require 'rails_helper'
require Rails.root.join('lib/ucf_transformer')

RSpec.describe UcfTransformer do
  describe '#ucf_to_regex' do
    context 'when handling curly brace quantifiers' do
      it 'supports exact range {2,3}' do
        regex = described_class.ucf_to_regex('A_{2,3}B')
        expect('AxxB').to match(regex)           # 2 chars
        expect('AxxxB').to match(regex)          # 3 chars
        expect('AxB').not_to match(regex)        # only 1 char
        expect('AxxxxxxxB').not_to match(regex)  # many chars
      end

      it 'supports optional {0,1}' do
        regex = described_class.ucf_to_regex('A_{0,1}B')
        expect('AB').to match(regex)       # 0 chars
        expect('AxB').to match(regex)      # 1 char
        expect('AxxB').not_to match(regex) # 2 chars
      end

      it 'supports one or more {1,}' do
        regex = described_class.ucf_to_regex('A_{1,}B')
        expect('AxB').to match(regex)      # 1 char
        expect('AxxxxB').to match(regex)   # many chars
        expect('AB').not_to match(regex)   # 0 chars
      end
    end

    context 'when handling dot characters' do
      it 'escapes literal dots' do
        regex = described_class.ucf_to_regex('A.B')
        expect(regex).to be_a(Regexp)
        expect('A.B').to match(regex)
        expect('AxB').not_to match(regex)
      end
    end

    context 'when handling underscores' do
      it 'treats underscore as any single character' do
        regex = described_class.ucf_to_regex('A_B')
        expect('AxB').to match(regex)
        expect('AB').not_to match(regex)
        expect('ACDB').not_to match(regex)
      end

      it 'treats underscore as any two character' do
        regex = described_class.ucf_to_regex('A__B')
        expect('AxyB').to match(regex)
        expect('AB').not_to match(regex)
        expect('ACDEB').not_to match(regex)
      end
    end

    context 'when handling asterisks' do
      it 'treats asterisk as word characters, no space delimiter' do
        regex = described_class.ucf_to_regex('A*B')
        expect('AhelloB').to match(regex)
        expect('AB').not_to match(regex)
        expect('Ahello world B').not_to match(regex)
        expect('Ahello B').not_to match(regex)
      end

      it 'treats asterisk as a word characters, space delimiter' do
        regex = described_class.ucf_to_regex('A *')
        expect('A hello B').to match(regex)
        expect('AB').not_to match(regex)
        expect('A hello world B').to match(regex)
        expect('Ahello B').not_to match(regex)
      end

      it 'treats two asterisk as two word characters, space delimiter' do
        regex = described_class.ucf_to_regex('A* *')
        expect('Ahello world').to match(regex)
        expect('AB').not_to match(regex)
        expect('Ahello B').to match(regex)
        expect('Ahello world 123').to match(regex)
        expect('Ahello world B').to match(regex)
      end
    end

    context 'when handling square brackets' do
      it 'preserves character classes inside square brackets' do
        regex = described_class.ucf_to_regex('A[BCX]D')
        expect('ABD').to match(regex)
        expect('ACD').to match(regex)
        expect('AXD').to match(regex)
        expect('AED').not_to match(regex)
      end

      it 'supports ranges inside square brackets' do
        regex = described_class.ucf_to_regex('A[0-9]B')
        expect('A1B').to match(regex)
        expect('A9B').to match(regex)
        expect('A88B').not_to match(regex)
      end
    end

    context 'when invalid regex is given' do
      it 'returns the original string on RegexpError' do
        bad_pattern = 'A[' # incomplete bracket
        result = described_class.ucf_to_regex(bad_pattern)
        expect(result).to eq(bad_pattern)
      end
    end
  end
end
