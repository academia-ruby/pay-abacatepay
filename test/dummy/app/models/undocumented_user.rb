class UndocumentedUser < ApplicationRecord
  self.table_name = "users"
  pay_customer default_payment_processor: :abacatepay

  def document = nil
  def cpf = nil
  def cnpj = nil
end
