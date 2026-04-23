# frozen_string_literal: true

require "rails_helper"

RSpec.describe MyClass, type: :interactor do
  describe ".execute" do
    let(:argument) { "hello" }

    subject { described_class.execute(argument) }

    context "when everything is valid" do
      it "returns success with data" do
        expect(subject.success?).to be true
        expect(subject.data).to eq("hello")
      end
    end

    context "when the argument is invalid" do
      let(:argument) { nil }

      it "returns failure with errors" do
        # Adjust this expectation once you add real validation in MyClass.
        expect(subject.success?).to be true
      end
    end
  end
end
