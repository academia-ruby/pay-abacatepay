class CpfUser < ApplicationRecord
  self.table_name = "users"
  pay_customer default_payment_processor: :abacatepay

  def document = nil
  def cpf = "987.654.321-00"
end
