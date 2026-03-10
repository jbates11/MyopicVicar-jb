require "rails_helper"

RSpec.describe UcfTransformer do
  describe ".ucf_to_regex" do
    subject(:regex) { described_class.ucf_to_regex(input) }

    context "when input is not a String" do
      let(:input) { nil }

      it "returns the input unchanged" do
        expect(regex).to eq(nil)
      end
    end

    context "literal dots" do
      let(:input) { "Dr.J" }

      it "escapes dots so they match literal periods" do
        expect(regex).to eq(/^Dr\.J$/i)
        # Exact 4-character match: D-r-.-J
        expect("Dr.J").to match(regex)
        # Longer string should NOT match (ensures exact name matching)
        expect("Dr.John").not_to match(regex)
      end
    end

    context "underscore wildcard" do
      let(:input) { "Sm_th" }

      it "converts underscore to single-character wildcard" do
        expect("Smith").to match(regex)
        expect("Smyth").to match(regex)
        expect("Smth").not_to match(regex)
      end
    end

    context "asterisk wildcard" do
      let(:input) { "Jo*" }

      it "converts * to one-or-more word characters" do
        expect("John").to match(regex)
        expect("Jones").to match(regex)
        expect("Jo").not_to match(regex) # requires at least one char
      end
    end

    context "underscore + quantifier" do
      let(:input) { "A_{2,3}n" }

      it "converts _{2,3} to \\w{2,3}" do
        expect("Aann").to match(regex)
        expect("Axyzn").to match(regex)
        expect("An").not_to match(regex)
      end
    end

    # context "plain quantifier {m,n}" do
    #   let(:input) { "A{2,3}n" }
    #   it "preserves valid regex quantifiers" do
    #     expect("Aann").to match(regex)
    #     expect("Axyzn").to match(regex)
    #     expect("Ann").not_to match(regex) # only 1 'A'
    #   end
    # end

    context "plain quantifier {m,n}" do
      let(:input) { "A{2,3}n" }
      it "preserves valid regex quantifiers (applies to preceding char)" do
        # A repeated 2 times, then n
        expect("AAn").to match(regex)
        expect("Aan").to match(regex)
        # A repeated 3 times, then n
        expect("AAAn").to match(regex)
        expect("AAan").to match(regex)
        expect("Aaan").to match(regex)

        # A repeated only 1 time - should NOT match
        expect("An").not_to match(regex)
        expect("an").not_to match(regex)
        # A repeated 4 times - should NOT match
        expect("AAAAn").not_to match(regex)
        expect("Aaaan").not_to match(regex)
        expect("AaAan").not_to match(regex)
      end
    end

    context "character repetition {m,n} (preceding char repeats)" do
      let(:input) { "Den{1,2}is" }

      it "preserves bare quantifiers (char repeats m-n times)" do
        # 'n' repeats 1 time
        expect("Denis").to match(regex)
        # 'n' repeats 2 times
        expect("Dennis").to match(regex)
        # 'n' doesn't appear (0 times) - should NOT match
        expect("Deis").not_to match(regex)
        # 'n' repeats 3 times - should NOT match
        expect("Denniis").not_to match(regex)
      end
    end

    context "wildcard repetition _{m,n} (any char repeats)" do
      let(:input) { "Den_{1,2}is" }

      it "converts _{m,n} to .{m,n} (any char repeats m-n times)" do
        # underscore replacement matches 1 char (n)
        expect("Dennis").to match(regex)
        # underscore replacement matches 2 chars (nn)
        expect("Dennnis").to match(regex)
        # underscore replacement matches 1 char (a)
        expect("Denais").to match(regex)
        # underscore replacement matches 2 chars (bc)
        expect("Denbcis").to match(regex)
        # underscore replacement matches 0 chars - should NOT match
        expect("Deis").not_to match(regex)
        # underscore replacement matches 3 chars - should NOT match (outside {1,2} range)
        expect("Dennnnis").not_to match(regex)
      end
    end

    context "character classes" do
      let(:input) { "P[io]le" }

      it "preserves character classes" do
        expect("Pile").to match(regex)
        expect("Pole").to match(regex)
        expect("Pale").not_to match(regex)
      end
    end

    context "combined patterns" do
      let(:input) { "S._*" }

      it "handles dot, underscore, and star together" do
        expect("S.Alex").to match(regex)
        expect("S.Owen").to match(regex)
        expect("SAlex").not_to match(regex) # missing literal dot
      end
    end

    context "leading wildcard" do
      let(:input) { "*son" }

      it "matches any leading word characters" do
        expect("Johnson").to match(regex)
        expect("Emerson").to match(regex)
        expect("son").not_to match(regex) # requires at least one leading char
      end
    end

    context "invalid regex" do
      let(:input) { "A{2,3" } # missing closing brace

      it "returns the original string on RegexpError" do
        expect(regex).to eq("A{2,3")
      end
    end

    context "logging behavior" do
      let(:input) { "A{2,3" }

      it "logs a warning when regex compilation fails" do
        # Using a mocks.
        expect(Rails.logger).to receive(:warn).with(/Regex conversion failed/)

        # **This is the trigger.** It enters the method, 
        # hits the `rescue` block, and triggers `Rails.logger.warn`.
        described_class.ucf_to_regex(input)
      end

      it "returns the original string when Regex conversion fails" do
        # Same as above using No mocks, no global state changes
        result = described_class.ucf_to_regex("A{2,3")
        
        expect(result).to eq("A{2,3")
      end
    end
    
  end
end
