require 'rspec/core'
require 'pry'

describe "example spec" do
  it "succeeds" do
    expect(true).to eq(true)
  end

  it "gets debugged" do
    binding.pry
    expect(true).to eq(true)
  end
end
