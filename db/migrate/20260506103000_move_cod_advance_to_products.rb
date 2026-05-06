# frozen_string_literal: true

class MoveCodAdvanceToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :cod_minimum_advance, :decimal, precision: 10, scale: 2, null: false, default: 0.0
    remove_column :sellers, :cod_minimum_advance, :decimal
  end
end
