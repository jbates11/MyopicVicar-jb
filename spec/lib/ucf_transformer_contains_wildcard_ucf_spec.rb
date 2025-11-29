require 'rails_helper'
require Rails.root.join('lib/ucf_transformer')

RSpec.describe UcfTransformer do
  describe '#contains_wildcard_ucf?' do
    context 'when name_part is blank' do
      it 'returns false for nil' do
        expect(UcfTransformer.contains_wildcard_ucf?(nil)).to eq(false)
      end

      it 'returns false for empty string' do
        expect(UcfTransformer.contains_wildcard_ucf?("")).to eq(false)
      end

      it 'returns false for whitespace only' do
        expect(UcfTransformer.contains_wildcard_ucf?("   ")).to eq(false)
      end
    end

    context 'when name_part contains no wildcard characters' do
      it 'returns false for a normal name' do
        expect(UcfTransformer.contains_wildcard_ucf?("Smith")).to eq(false)
      end
    end

    context 'when name_part contains wildcard characters' do
      it 'detects *' do
        expect(UcfTransformer.contains_wildcard_ucf?("Sm*th")).to eq(true)
      end

      it 'detects _' do
        expect(UcfTransformer.contains_wildcard_ucf?("Sm_th")).to eq(true)
      end

      it 'detects ?' do
        expect(UcfTransformer.contains_wildcard_ucf?("Sm?th")).to eq(true)
      end

      it 'detects {' do
        expect(UcfTransformer.contains_wildcard_ucf?("Sm{th")).to eq(true)
      end

      it 'detects }' do
        expect(UcfTransformer.contains_wildcard_ucf?("Sm}th")).to eq(true)
      end

      it 'detects [' do
        expect(UcfTransformer.contains_wildcard_ucf?("Sm[th")).to eq(true)
      end

      it 'detects ]' do
        expect(UcfTransformer.contains_wildcard_ucf?("Sm]th")).to eq(true)
      end
    end

    context 'when name_part contains multiple wildcards' do
      it 'returns true if any are present' do
        expect(UcfTransformer.contains_wildcard_ucf?("Sm*th?")).to eq(true)
        expect(UcfTransformer.contains_wildcard_ucf?("Sm{th]")).to eq(true)
      end
    end
  end
end
