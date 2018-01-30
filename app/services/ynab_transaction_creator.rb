class YNABTransactionCreator
  def initialize(time, amount, payee_name, description, cleared: true)
    @time = time
    @amount = amount
    @payee_name = payee_name
    @description = description
    @cleared = cleared

    @client = YNABClient.new(ENV['YNAB_ACCESS_TOKEN'])
  end

  def create
    payee_id = lookup_payee_id(@payee_name)
    category_id = lookup_category_id(payee_id)

    return :duplicate if is_duplicate_transaction?(payee_id, category_id)

    create = @client.create_transaction(
      budget_id: selected_budget_id,
      account_id: selected_account_id,
      payee_id: payee_id,
      category_id: category_id,
      amount: @amount,
      cleared: @cleared,
      date: @time.to_date,
      memo: @description
    )

    create.try(:[], :transaction).present? ? create : :failed
  end

  private

  def is_duplicate_transaction?(payee_id, category_id)
    transactions.any? do |transaction|
      transaction[:date] == @time.to_date.to_s &&
        transaction[:amount] == @amount &&
        transaction[:payee_id] == payee_id &&
        transaction[:category_id] == category_id
    end
  end

  def lookup_category_id(payee_id)
    transactions.select{|a| a[:payee_id] == payee_id }.last.try(:[], :category_id)
  end

  def lookup_payee_id(payee_name)
    @client.payees(selected_budget_id).select{|p| p[:name].downcase == payee_name.to_s.downcase }.first.try(:[], :id)
  end

  def selected_budget_id
    @_selected_budget_id ||= ENV['YNAB_BUDGET_ID'] || @client.budgets.first[:id]
  end

  def selected_account_id
    @_selected_account_id ||= ENV['YNAB_ACCOUNT_ID'] || @client.accounts(selected_budget_id).reject{|a| a[:closed]}.select{|a| a[:type] == 'Checking'}.first[:id]
  end

  def transactions
    @_transactions ||= @client.transactions(selected_budget_id)
  end
end
