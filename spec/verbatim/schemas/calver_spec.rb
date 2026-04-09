# frozen_string_literal: true

require "spec_helper"

RSpec.describe Verbatim::Schemas::CalVer do
  describe ".parse" do
    it "parses unpadded components" do
      v = described_class.parse("2026.4.8")
      expect(v.year).to eq(2026)
      expect(v.month).to eq(4)
      expect(v.day).to eq(8)
    end

    it "parses zero-padded components" do
      v = described_class.parse("2026.04.08")
      expect(v.year).to eq(2026)
      expect(v.month).to eq(4)
      expect(v.day).to eq(8)
    end

    it "formats with zero-padded month and day" do
      expect(described_class.parse("2026.4.8").to_s).to eq("2026.04.08")
    end

    it "round-trips canonical strings" do
      s = "2026.12.31"
      expect(described_class.parse(s).to_s).to eq(s)
    end

    it "rejects month out of range" do
      expect { described_class.parse("2026.13.01") }.to raise_error(Verbatim::ParseError, /maximum/)
    end

    it "rejects day out of range" do
      expect { described_class.parse("2026.01.32") }.to raise_error(Verbatim::ParseError, /maximum/)
    end

    it "rejects zero month" do
      expect { described_class.parse("2026.0.15") }.to raise_error(Verbatim::ParseError, /minimum/)
    end

    it "does not validate real calendar dates" do
      v = described_class.parse("2026.02.31")
      expect(v.to_s).to eq("2026.02.31")
    end
  end

  describe "Comparable" do
    it "sorts chronologically" do
      strings = %w[2026.04.08 2025.12.31 2026.04.07 2026.12.01]
      sorted = strings.shuffle.map { described_class.parse(_1) }.sort.map(&:to_s)
      expect(sorted).to eq(%w[2025.12.31 2026.04.07 2026.04.08 2026.12.01])
    end
  end

  describe "#succ" do
    it "advances one calendar day" do
      v = described_class.parse("2026.04.08")
      expect(v.succ.to_s).to eq("2026.04.09")
    end

    it "rolls month boundary" do
      expect(described_class.parse("2026.04.30").succ.to_s).to eq("2026.05.01")
    end

    it "rolls year boundary" do
      expect(described_class.parse("2026.12.31").succ.to_s).to eq("2027.01.01")
    end

    it "raises on invalid calendar dates" do
      v = described_class.parse("2026.02.31")
      expect { v.succ }.to raise_error(ArgumentError, /invalid calendar date/)
    end
  end

  describe "#pred" do
    it "goes back one calendar day" do
      v = described_class.parse("2026.04.08")
      expect(v.pred.to_s).to eq("2026.04.07")
    end

    it "rolls month boundary" do
      expect(described_class.parse("2026.05.01").pred.to_s).to eq("2026.04.30")
    end

    it "raises on invalid calendar dates" do
      v = described_class.parse("2026.02.31")
      expect { v.pred }.to raise_error(ArgumentError, /invalid calendar date/)
    end
  end
end
