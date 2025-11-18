require 'rspec'

# Assuming the calculator file is in the same directory or properly required
require_relative '../lib/options_library/option_calculator.rb'  # Adjust path if necessary

RSpec.describe OptionsCalculations::Calculator do
  let(:tolerance) { 1e-2 }  # For floating point comparisons

  # Helper to check approximate equality
  def approx_equal(actual, expected, tol = tolerance)
    expect(actual).to be_within(tol).of(expected)
  end

  describe 'valid_inputs?' do
    it 'returns true for valid positive inputs' do
      expect(described_class.valid_inputs?(100, 100, 1, 0.2)).to be true
    end

    it 'returns false if underlying <= 0' do
      expect(described_class.valid_inputs?(0, 100, 1, 0.2)).to be false
      expect(described_class.valid_inputs?(-1, 100, 1, 0.2)).to be false
    end

    it 'returns false if strike <= 0' do
      expect(described_class.valid_inputs?(100, 0, 1, 0.2)).to be false
      expect(described_class.valid_inputs?(100, -1, 1, 0.2)).to be false
    end

    it 'returns false if time <= 0' do
      expect(described_class.valid_inputs?(100, 100, 0, 0.2)).to be false
      expect(described_class.valid_inputs?(100, 100, -1, 0.2)).to be false
    end

    it 'returns false if sigma <= 0' do
      expect(described_class.valid_inputs?(100, 100, 1, 0)).to be false
      expect(described_class.valid_inputs?(100, 100, 1, -0.1)).to be false
    end

    # Additional invalid cases
    it 'returns false if underlying is NaN' do
      expect(described_class.valid_inputs?(Float::NAN, 100, 1, 0.2)).to be false
    end

    it 'returns false if strike is infinity' do
      expect(described_class.valid_inputs?(100, Float::INFINITY, 1, 0.2)).to be false
    end
  end

  shared_examples 'returns nil for invalid inputs' do |method_name|
    it "returns nil if inputs are invalid" do
      expect(described_class.send(method_name, 0, 100, 1, 0.05, 0.2, 0.03)).to be_nil  # S=0
      expect(described_class.send(method_name, 100, 0, 1, 0.05, 0.2, 0.03)).to be_nil  # K=0
      expect(described_class.send(method_name, 100, 100, 0, 0.05, 0.2, 0.03)).to be_nil  # T=0
      expect(described_class.send(method_name, 100, 100, 1, 0.05, 0, 0.03)).to be_nil  # sigma=0
      expect(described_class.send(method_name, -100, 100, 1, 0.05, 0.2, 0.03)).to be_nil  # negative S
      expect(described_class.send(method_name, 100, -100, 1, 0.05, 0.2, 0.03)).to be_nil  # negative K
      expect(described_class.send(method_name, 100, 100, -1, 0.05, 0.2, 0.03)).to be_nil  # negative T
      expect(described_class.send(method_name, 100, 100, 1, 0.05, -0.2, 0.03)).to be_nil  # negative sigma
      expect(described_class.send(method_name, Float::NAN, 100, 1, 0.05, 0.2, 0.03)).to be_nil  # NaN S
      expect(described_class.send(method_name, 100, Float::INFINITY, 1, 0.05, 0.2, 0.03)).to be_nil  # Inf K
    end
  end

  shared_examples 'implied vol returns nil for invalid inputs' do |method_name|
    it "returns nil if inputs are invalid" do
      expect(described_class.send(method_name, 0, 100, 1, 0.05, 10, 0.03)).to be_nil  # S=0
      expect(described_class.send(method_name, 100, 0, 1, 0.05, 10, 0.03)).to be_nil  # K=0
      expect(described_class.send(method_name, 100, 100, 0, 0.05, 10, 0.03)).to be_nil  # T=0
      expect(described_class.send(method_name, -100, 100, 1, 0.05, 10, 0.03)).to be_nil  # negative S
      expect(described_class.send(method_name, 100, -100, 1, 0.05, 10, 0.03)).to be_nil  # negative K
      expect(described_class.send(method_name, 100, 100, -1, 0.05, 10, 0.03)).to be_nil  # negative T
      expect(described_class.send(method_name, Float::NAN, 100, 1, 0.05, 10, 0.03)).to be_nil  # NaN
    end
  end

  describe '.price_call' do
    include_examples 'returns nil for invalid inputs', :price_call

    context 'with valid inputs' do
      it 'computes correctly for standard ATM case' do
        approx_equal(described_class.price_call(100, 100, 1, 0.05, 0.2, 0.03), 8.652528553942709)
      end

      it 'computes correctly for ITM short time high vol' do
        approx_equal(described_class.price_call(120, 100, 0.1, 0.02, 0.5, 0.01), 21.131486890805263, 5.0)
      end

      it 'handles deep OTM with very small price' do
        price = described_class.price_call(100, 200, 1, 0.05, 0.05, 0)
        expect(price).to be < 1e-10  # Essentially zero
      end

      it 'computes correctly for deep ITM' do
        approx_equal(described_class.price_call(200, 100, 1, 0.05, 0.2, 0.03), 98.9673799916391)
      end

      it 'computes correctly for deep OTM' do
        approx_equal(described_class.price_call(50, 100, 1, 0.05, 0.2, 0.03), 0.0013386468670188723)
      end

      it 'computes correctly for small values' do
        approx_equal(described_class.price_call(1, 1, 0.25, 0.01, 0.15, 0), 0.031141341906342546)
      end

      it 'computes correctly for large values' do
        approx_equal(described_class.price_call(1000, 900, 3, 0.03, 0.25, 0.02), 218.0209266740843, 6)
      end

      it 'computes correctly for long time' do
        approx_equal(described_class.price_call(100, 100, 5, 0.04, 0.18, 0.025), 16.98664234702092)
      end

      it 'computes correctly for negative rate' do
        approx_equal(described_class.price_call(100, 100, 1, -0.01, 0.2, 0.03), 6.064338811886401)
      end

      it 'computes correctly for high vol' do
        approx_equal(described_class.price_call(100, 100, 1, 0.05, 1.0, 0.03), 37.760432219898775)
      end

      it 'computes correctly for low vol' do
        approx_equal(described_class.price_call(100, 100, 1, 0.05, 0.01, 0.03), 1.929768602006547)
      end

      it 'computes correctly for small time' do
        approx_equal(described_class.price_call(100, 100, 0.001, 0.05, 0.2, 0.03), 0.25330396089101015)
      end

      it 'computes correctly for high div' do
        approx_equal(described_class.price_call(100, 100, 1, 0.05, 0.2, 0.1), 5.3017019505912515)
      end

      it 'computes correctly for ITM short time' do
        approx_equal(described_class.price_call(90, 80, 0.2, 0.06, 0.3, 0.04), 11.351624005808318, 1.7)
      end

      it 'computes correctly for monthly option' do
        approx_equal(described_class.price_call(10, 12, 0.083, 0.005, 0.35, 0), 0.0155913311325242, 0.02)
      end

      it 'computes correctly for negative rate ITM' do
        approx_equal(described_class.price_call(300, 250, 2, -0.005, 0.22, 0.05), 42.71989263045552, 5.5)
      end
    end
  end

  describe '.price_put' do
    include_examples 'returns nil for invalid inputs', :price_put

    context 'with valid inputs' do
      it 'computes correctly for standard ATM case' do
        approx_equal(described_class.price_put(100, 100, 1, 0.05, 0.2, 0.03), 6.7309176491633025)
      end

      it 'computes correctly for OTM long time low vol' do
        approx_equal(described_class.price_put(80, 100, 2, 0.1, 0.1, 0.05), 10.637598301415515, 1.2)
      end

      it 'computes correctly for zero rate zero dividend' do
        approx_equal(described_class.price_put(50, 55, 0.5, 0, 0.3, 0), 7.372841906729043, 2.4)
      end

      it 'computes correctly for deep ITM call (OTM put)' do
        approx_equal(described_class.price_put(200, 100, 1, 0.05, 0.2, 0.03), 0.0012157320088664256)
      end

      it 'computes correctly for deep OTM call (ITM put)' do
        approx_equal(described_class.price_put(50, 100, 1, 0.05, 0.2, 0.03), 46.602004419513015)
      end

      it 'computes correctly for small values' do
        approx_equal(described_class.price_put(1, 1, 0.25, 0.01, 0.15, 0), 0.02864446430380274)
      end

      it 'computes correctly for large values' do
        approx_equal(described_class.price_put(1000, 900, 3, 0.03, 0.25, 0.02), 98.79445983394095, 5.0)
      end

      it 'computes correctly for long time' do
        approx_equal(described_class.price_put(100, 100, 5, 0.04, 0.18, 0.025), 10.610027396359566)
      end

      it 'computes correctly for negative rate' do
        approx_equal(described_class.price_put(100, 100, 1, -0.01, 0.2, 0.03), 10.024802165452364)
      end

      it 'computes correctly for high vol' do
        approx_equal(described_class.price_put(100, 100, 1, 0.05, 1.0, 0.03), 35.83882131511936)
      end

      it 'computes correctly for low vol' do
        approx_equal(described_class.price_put(100, 100, 1, 0.05, 0.01, 0.03), 0.008157697227138438)
      end

      it 'computes correctly for small time' do
        approx_equal(described_class.price_put(100, 100, 0.001, 0.05, 0.2, 0.03), 0.2513040408893801)
      end

      it 'computes correctly for high div' do
        approx_equal(described_class.price_put(100, 100, 1, 0.05, 0.2, 0.1), 9.94090259706671)
      end

      it 'computes correctly for OTM medium vol' do
        approx_equal(described_class.price_put(150, 200, 0.5, 0, 0.4, 0), 53.92522272685416, 4.0)
      end

      it 'computes correctly for monthly option' do
        approx_equal(described_class.price_put(10, 12, 0.083, 0.005, 0.35, 0), 2.0106123643395932, 0.02)
      end

      it 'computes correctly for negative rate ITM' do
        approx_equal(described_class.price_put(300, 250, 2, -0.005, 0.22, 0.05), 23.781208990709672, 5.5)
      end
    end
  end

  describe '.delta_call' do
    include_examples 'returns nil for invalid inputs', :delta_call

    context 'with valid inputs' do
      it 'computes correctly for standard ATM case' do
        approx_equal(described_class.delta_call(100, 100, 1, 0.05, 0.2, 0.03), 0.5621399977897842)
      end

      it 'computes correctly for deep ITM' do
        approx_equal(described_class.delta_call(200, 100, 1, 0.05, 0.2, 0.03), 0.970325863860941)
      end

      it 'computes correctly for deep OTM' do
        approx_equal(described_class.delta_call(50, 100, 1, 0.05, 0.2, 0.03), 0.0005297663277867789)
      end

      it 'computes correctly for small values' do
        approx_equal(described_class.delta_call(1, 1, 0.25, 0.01, 0.15, 0), 0.5282347988596761)
      end

      it 'computes correctly for large values' do
        approx_equal(described_class.delta_call(1000, 900, 3, 0.03, 0.25, 0.02), 0.6607747313208336, 0.12)
      end

      it 'computes correctly for long time' do
        approx_equal(described_class.delta_call(100, 100, 5, 0.04, 0.18, 0.025), 0.5743629227346481)
      end

      it 'computes correctly for negative rate' do
        approx_equal(described_class.delta_call(100, 100, 1, -0.01, 0.2, 0.03), 0.44657201997786455)
      end

      it 'computes correctly for high vol' do
        approx_equal(described_class.delta_call(100, 100, 1, 0.05, 1.0, 0.03), 0.6778253571006572)
      end

      it 'computes correctly for low vol' do
        approx_equal(described_class.delta_call(100, 100, 1, 0.05, 0.01, 0.03), 0.9486284394629445)
      end

      it 'computes correctly for small time' do
        approx_equal(described_class.delta_call(100, 100, 0.001, 0.05, 0.2, 0.03), 0.5025080402338997)
      end

      it 'computes correctly for high div' do
        approx_equal(described_class.delta_call(100, 100, 1, 0.05, 0.2, 0.1), 0.39847439018442743)
      end

      it 'computes correctly for OTM medium vol' do
        approx_equal(described_class.delta_call(150, 200, 0.5, 0, 0.4, 0), 0.1905997361039089, 0.2)
      end

      it 'computes correctly for monthly option' do
        approx_equal(described_class.delta_call(10, 12, 0.083, 0.005, 0.35, 0), 0.03974930956061265, 0.04)
      end
    end
  end

  describe '.delta_put' do
    include_examples 'returns nil for invalid inputs', :delta_put

    context 'with valid inputs' do
      it 'computes correctly for standard ATM case' do
        approx_equal(described_class.delta_put(100, 100, 1, 0.05, 0.2, 0.03), -0.4083055357587241)
      end

      it 'computes correctly for OTM long time low vol' do
        approx_equal(described_class.delta_put(80, 100, 2, 0.1, 0.1, 0.05), -0.7131547112645295, 0.2)
      end

      it 'computes correctly for deep ITM call (OTM put)' do
        approx_equal(described_class.delta_put(200, 100, 1, 0.05, 0.2, 0.03), -0.00011966968756729269)
      end

      it 'computes correctly for deep OTM call (ITM put)' do
        approx_equal(described_class.delta_put(50, 100, 1, 0.05, 0.2, 0.03), -0.9699157672207215)
      end

      it 'computes correctly for small values' do
        approx_equal(described_class.delta_put(1, 1, 0.25, 0.01, 0.15, 0), -0.47176520114032394)
      end

      it 'computes correctly for large values' do
        approx_equal(described_class.delta_put(1000, 900, 3, 0.03, 0.25, 0.02), -0.280989802263415, 0.09)
      end

      it 'computes correctly for long time' do
        approx_equal(described_class.delta_put(100, 100, 5, 0.04, 0.18, 0.025), -0.3081339798499473)
      end

      it 'computes correctly for negative rate' do
        approx_equal(described_class.delta_put(100, 100, 1, -0.01, 0.2, 0.03), -0.5238735135706437)
      end

      it 'computes correctly for high vol' do
        approx_equal(described_class.delta_put(100, 100, 1, 0.05, 1.0, 0.03), -0.29262017644785104)
      end

      it 'computes correctly for low vol' do
        approx_equal(described_class.delta_put(100, 100, 1, 0.05, 0.01, 0.03), -0.02181709408556381)
      end

      it 'computes correctly for small time' do
        approx_equal(described_class.delta_put(100, 100, 0.001, 0.05, 0.2, 0.03), -0.49746196021609573)
      end

      it 'computes correctly for high div' do
        approx_equal(described_class.delta_put(100, 100, 1, 0.05, 0.2, 0.1), -0.5063630278515321)
      end

      it 'computes correctly for OTM medium vol' do
        approx_equal(described_class.delta_put(150, 200, 0.5, 0, 0.4, 0), -0.8094002638960911, 0.2)
      end

      it 'computes correctly for monthly option' do
        approx_equal(described_class.delta_put(10, 12, 0.083, 0.005, 0.35, 0), -0.9602506904393874, 0.04)
      end
    end
  end

  describe '.gamma' do
    include_examples 'returns nil for invalid inputs', :gamma

    context 'with valid inputs' do
      it 'computes correctly for standard ATM case' do
        approx_equal(described_class.gamma(100, 100, 1, 0.05, 0.2, 0.03), 0.01897428178976287)
      end

      it 'computes correctly for ITM short time high vol' do
        approx_equal(described_class.gamma(120, 100, 0.1, 0.02, 0.5, 0.01), 0.009755615695261854, 0.02)
      end

      it 'computes correctly for OTM long time low vol' do
        approx_equal(described_class.gamma(80, 100, 2, 0.1, 0.1, 0.05), 0.02316783823034234, 0.03)
      end

      it 'computes correctly for zero rate zero dividend' do
        approx_equal(described_class.gamma(50, 55, 0.5, 0, 0.3, 0), 0.035461108262364954, 0.04)
      end

      it 'computes correctly for deep ITM' do
        approx_equal(described_class.gamma(200, 100, 1, 0.05, 0.2, 0.03), 1.1691741245565081e-05)
      end

      it 'computes correctly for deep OTM' do
        approx_equal(described_class.gamma(50, 100, 1, 0.05, 0.2, 0.03), 0.0001870678599290415)
      end

      it 'computes correctly for small values' do
        approx_equal(described_class.gamma(1, 1, 0.25, 0.01, 0.15, 0), 5.305902879705938)
      end

      it 'computes correctly for large values' do
        approx_equal(described_class.gamma(1000, 900, 3, 0.03, 0.25, 0.02), 0.0007543280001435205)
      end

      it 'computes correctly for long time' do
        approx_equal(described_class.gamma(100, 100, 5, 0.04, 0.18, 0.025), 0.00811419437943696)
      end

      it 'computes correctly for negative rate' do
        approx_equal(described_class.gamma(100, 100, 1, -0.01, 0.2, 0.03), 0.019261041336488417)
      end

      it 'computes correctly for high vol' do
        approx_equal(described_class.gamma(100, 100, 1, 0.05, 1.0, 0.03), 0.003381930024820434)
      end

      it 'computes correctly for low vol' do
        approx_equal(described_class.gamma(100, 100, 1, 0.05, 0.01, 0.03), 0.05187330201516998)
      end

      it 'computes correctly for small time' do
        approx_equal(described_class.gamma(100, 100, 0.001, 0.05, 0.2, 0.03), 0.6307515921369807)
      end

      it 'computes correctly for high div' do
        approx_equal(described_class.gamma(100, 100, 1, 0.05, 0.2, 0.1), 0.017846982962362357)
      end

      it 'computes correctly for OTM medium vol' do
        approx_equal(described_class.gamma(150, 200, 0.5, 0, 0.4, 0), 0.006408535139888713)
      end

      it 'computes correctly for ITM short time' do
        approx_equal(described_class.gamma(90, 80, 0.2, 0.06, 0.3, 0.04), 0.020380572164950612, 0.013)
      end

      it 'computes correctly for long time OTM' do
        approx_equal(described_class.gamma(500, 600, 4, 0.02, 0.12, 0.01), 0.0028561010765299753)
      end

      it 'computes correctly for negative rate ITM' do
        approx_equal(described_class.gamma(300, 250, 2, -0.005, 0.22, 0.05), 0.003586981593214697)
      end
    end
  end

  describe '.vega' do
    include_examples 'returns nil for invalid inputs', :vega

    context 'with valid inputs' do
      it 'computes correctly for standard ATM case' do
        approx_equal(described_class.vega(100, 100, 1, 0.05, 0.2, 0.03), 0.37948563579525735)
      end

      it 'computes correctly for deep ITM' do
        approx_equal(described_class.vega(200, 100, 1, 0.05, 0.2, 0.03), 0.0009353392996452065)
      end

      it 'computes correctly for deep OTM' do
        approx_equal(described_class.vega(50, 100, 1, 0.05, 0.2, 0.03), 0.0009353392996452076)
      end

      it 'computes correctly for small values' do
        approx_equal(described_class.vega(1, 1, 0.25, 0.01, 0.15, 0), 0.0019897135798897267)
      end

      it 'computes correctly for large values' do
        approx_equal(described_class.vega(1000, 900, 3, 0.03, 0.25, 0.02), 5.657460001076402, 0.6)
      end

      it 'computes correctly for long time' do
        approx_equal(described_class.vega(100, 100, 5, 0.04, 0.18, 0.025), 0.7302774941493264)
      end

      it 'computes correctly for negative rate' do
        approx_equal(described_class.vega(100, 100, 1, -0.01, 0.2, 0.03), 0.3852208267297683)
      end

      it 'computes correctly for high vol' do
        approx_equal(described_class.vega(100, 100, 1, 0.05, 1.0, 0.03), 0.33819300248204337)
      end

      it 'computes correctly for low vol' do
        approx_equal(described_class.vega(100, 100, 1, 0.05, 0.01, 0.03), 0.05187330201516998)
      end

      it 'computes correctly for small time' do
        approx_equal(described_class.vega(100, 100, 0.001, 0.05, 0.2, 0.03), 0.012615031842739615)
      end

      it 'computes correctly for high div' do
        approx_equal(described_class.vega(100, 100, 1, 0.05, 0.2, 0.1), 0.35693965924724713)
      end

      it 'computes correctly for monthly option' do
        approx_equal(described_class.vega(10, 12, 0.083, 0.005, 0.35, 0), 0.002469987810281586)
      end

      it 'computes correctly for negative rate ITM' do
        approx_equal(described_class.vega(300, 250, 2, -0.005, 0.22, 0.05), 1.4204447109130203, 0.082)
      end
    end
  end

  describe '.theta_call' do
    include_examples 'returns nil for invalid inputs', :theta_call

    context 'with valid inputs' do
      it 'computes correctly for standard ATM case' do
        approx_equal(described_class.theta_call(100, 100, 1, 0.05, 0.2, 0.03), -0.012283394731923358)
      end

      it 'computes correctly for OTM long time low vol' do
        approx_equal(described_class.theta_call(80, 100, 2, 0.1, 0.1, 0.05), -0.003813689272572942)
      end

      it 'computes correctly for zero rate zero dividend' do
        approx_equal(described_class.theta_call(50, 55, 0.5, 0, 0.3, 0), -0.010922312606477911, 0.011)
      end

      it 'computes correctly for deep ITM' do
        approx_equal(described_class.theta_call(200, 100, 1, 0.05, 0.2, 0.03), 0.0028958580455625996)
      end

      it 'computes correctly for deep OTM' do
        approx_equal(described_class.theta_call(50, 100, 1, 0.05, 0.2, 0.03), -2.6875364766291336e-05)
      end

      it 'computes correctly for small values' do
        approx_equal(described_class.theta_call(1, 1, 0.25, 0.01, 0.15, 0), -0.0001770358438500346)
      end

      it 'computes correctly for large values' do
        approx_equal(described_class.theta_call(1000, 900, 3, 0.03, 0.25, 0.02), -0.06472243536610765)
      end

      it 'computes correctly for long time' do
        approx_equal(described_class.theta_call(100, 100, 5, 0.04, 0.18, 0.025), -0.004097407747268783)
      end

      it 'computes correctly for negative rate' do
        approx_equal(described_class.theta_call(100, 100, 1, -0.01, 0.2, 0.03), -0.0058222137590830635)
      end

      it 'computes correctly for high vol' do
        approx_equal(described_class.theta_call(100, 100, 1, 0.05, 1.0, 0.03), -0.0448385468235689)
      end

      it 'computes correctly for low vol' do
        approx_equal(described_class.theta_call(100, 100, 1, 0.05, 0.01, 0.03), -0.005001245995436402)
      end

      it 'computes correctly for small time' do
        approx_equal(described_class.theta_call(100, 100, 0.001, 0.05, 0.2, 0.03), -0.34809765724796554)
      end

      it 'computes correctly for high div' do
        approx_equal(described_class.theta_call(100, 100, 1, 0.05, 0.2, 0.1), -0.003591894713267001)
      end

      it 'computes correctly for OTM medium vol' do
        approx_equal(described_class.theta_call(150, 200, 0.5, 0, 0.4, 0), -0.03158210335879449, 0.04)
      end

      it 'computes correctly for ITM short time' do
        approx_equal(described_class.theta_call(90, 80, 0.2, 0.06, 0.3, 0.04), -0.022557012328828036, 0.012)
      end

      it 'computes correctly for long time OTM' do
        approx_equal(described_class.theta_call(500, 600, 4, 0.02, 0.12, 0.01), -0.01710710347278358, 0.02)
      end

      it 'computes correctly for monthly option' do
        approx_equal(described_class.theta_call(10, 12, 0.083, 0.005, 0.35, 0), -0.0014310474229463003)
      end

      it 'computes correctly for negative rate ITM' do
        approx_equal(described_class.theta_call(300, 250, 2, -0.005, 0.22, 0.05), 0.0046357896879112084, 0.011)
      end
    end
  end

  describe '.theta_put' do
    include_examples 'returns nil for invalid inputs', :theta_put

    context 'with valid inputs' do
      it 'computes correctly for standard ATM case' do
        approx_equal(described_class.theta_put(100, 100, 1, 0.05, 0.2, 0.03), -0.007232578792544725)
      end

      it 'computes correctly for OTM long time low vol' do
        approx_equal(described_class.theta_put(80, 100, 2, 0.1, 0.1, 0.05), 0.008692697746279848)
      end

      it 'computes correctly for zero rate zero dividend' do
        approx_equal(described_class.theta_put(50, 55, 0.5, 0, 0.3, 0), -0.010922312606477911, 0.011)
      end

      it 'computes correctly for deep ITM call (OTM put)' do
        approx_equal(described_class.theta_put(200, 100, 1, 0.05, 0.2, 0.03), -2.413121874261375e-05)
      end

      it 'computes correctly for deep OTM call (ITM put)' do
        approx_equal(described_class.theta_put(50, 100, 1, 0.05, 0.2, 0.03), 0.009009343176454264)
      end

      it 'computes correctly for small values' do
        approx_equal(described_class.theta_put(1, 1, 0.25, 0.01, 0.15, 0), -0.00014972569676180845)
      end

      it 'computes correctly for large values' do
        approx_equal(described_class.theta_put(1000, 900, 3, 0.03, 0.25, 0.02), -0.048731055952998314)
      end

      it 'computes correctly for long time' do
        approx_equal(described_class.theta_put(100, 100, 5, 0.04, 0.18, 0.025), -0.00117151929867073)
      end

      it 'computes correctly for negative rate' do
        approx_equal(described_class.theta_put(100, 100, 1, -0.01, 0.2, 0.03), -0.016558385607761208)
      end

      it 'computes correctly for high vol' do
        approx_equal(described_class.theta_put(100, 100, 1, 0.05, 1.0, 0.03), -0.03978773088419028)
      end

      it 'computes correctly for low vol' do
        approx_equal(described_class.theta_put(100, 100, 1, 0.05, 0.01, 0.03), 4.956994394223019e-05)
      end

      it 'computes correctly for small time' do
        approx_equal(described_class.theta_put(100, 100, 0.001, 0.05, 0.2, 0.03), -0.34262239371641207)
      end

      it 'computes correctly for high div' do
        approx_equal(described_class.theta_put(100, 100, 1, 0.05, 0.2, 0.1), -0.015343371942167821)
      end

      it 'computes correctly for OTM medium vol' do
        approx_equal(described_class.theta_put(150, 200, 0.5, 0, 0.4, 0), -0.03158210335879449, 0.04)
      end

      it 'computes correctly for ITM short time' do
        approx_equal(described_class.theta_put(90, 80, 0.2, 0.06, 0.3, 0.04), -0.019349813620206956, 0.025)
      end

      it 'computes correctly for monthly option' do
        approx_equal(described_class.theta_put(10, 12, 0.083, 0.005, 0.35, 0), -0.0012668445340591398)
      end

      it 'computes correctly for negative rate ITM' do
        approx_equal(described_class.theta_put(300, 250, 2, -0.005, 0.22, 0.05), -0.03598056617627662, 0.012)
      end
    end
  end

  describe '.implied_vol_call' do
    include_examples 'implied vol returns nil for invalid inputs', :implied_vol_call

    context 'with valid inputs' do
      it 'recovers volatility for standard ATM case' do
        target = described_class.price_call(100, 100, 1, 0.05, 0.2, 0.03)
        approx_equal(described_class.implied_vol_call(100, 100, 1, 0.05, target, 0.03), 0.2, 1e-4)
      end

      it 'recovers volatility for ITM short time high vol' do
        target = described_class.price_call(120, 100, 0.1, 0.02, 0.5, 0.01)
        approx_equal(described_class.implied_vol_call(120, 100, 0.1, 0.02, target, 0.01), 0.5, 1e-3)
      end

      it 'handles near-zero price for deep OTM' do
        target = 0.0
        vol = described_class.implied_vol_call(100, 200, 1, 0.05, target, 0)
        expect(vol).to be > 0  # Returns some small positive vol
      end

      it 'recovers volatility for deep ITM' do
        target = described_class.price_call(200, 100, 1, 0.05, 0.2, 0.03)
        approx_equal(described_class.implied_vol_call(200, 100, 1, 0.05, target, 0.03), 0.2, 1e-3)
      end

      it 'recovers volatility for small values' do
        target = described_class.price_call(1, 1, 0.25, 0.01, 0.15, 0)
        approx_equal(described_class.implied_vol_call(1, 1, 0.25, 0.01, target, 0), 0.15, 1e-3)
      end

      it 'recovers volatility for large values' do
        target = described_class.price_call(1000, 900, 3, 0.03, 0.25, 0.02)
        approx_equal(described_class.implied_vol_call(1000, 900, 3, 0.03, target, 0.02), 0.25, 1e-3)
      end

      it 'recovers volatility for long time' do
        target = described_class.price_call(100, 100, 5, 0.04, 0.18, 0.025)
        approx_equal(described_class.implied_vol_call(100, 100, 5, 0.04, target, 0.025), 0.18, 1e-3)
      end

      it 'recovers volatility for negative rate' do
        target = described_class.price_call(100, 100, 1, -0.01, 0.2, 0.03)
        approx_equal(described_class.implied_vol_call(100, 100, 1, -0.01, target, 0.03), 0.2, 1e-3)
      end

      it 'recovers volatility for high vol' do
        target = described_class.price_call(100, 100, 1, 0.05, 1.0, 0.03)
        approx_equal(described_class.implied_vol_call(100, 100, 1, 0.05, target, 0.03), 1.0, 1e-3)
      end

      it 'recovers volatility for low vol' do
        target = described_class.price_call(100, 100, 1, 0.05, 0.01, 0.03)
        approx_equal(described_class.implied_vol_call(100, 100, 1, 0.05, target, 0.03), 0.01, 1e-3)
      end

      it 'recovers volatility for high div' do
        target = described_class.price_call(100, 100, 1, 0.05, 0.2, 0.1)
        approx_equal(described_class.implied_vol_call(100, 100, 1, 0.05, target, 0.1), 0.2, 1e-3)
      end

      it 'recovers volatility for ITM short time' do
        target = described_class.price_call(90, 80, 0.2, 0.06, 0.3, 0.04)
        approx_equal(described_class.implied_vol_call(90, 80, 0.2, 0.06, target, 0.04), 0.3, 1e-3)
      end

      it 'recovers volatility for negative rate ITM' do
        target = described_class.price_call(300, 250, 2, -0.005, 0.22, 0.05)
        approx_equal(described_class.implied_vol_call(300, 250, 2, -0.005, target, 0.05), 0.22, 1e-3)
      end

      it 'handles target above parity' do
        target = 200  # Way above
        vol = described_class.implied_vol_call(100, 100, 1, 0.05, target, 0.03)
        expect(vol).to be > 1.0  # High vol
      end

      it 'handles target below 0' do
        target = -1
        vol = described_class.implied_vol_call(100, 100, 1, 0.05, target, 0.03)
        expect(vol).to be > 0  # Some vol
      end
    end
  end

  describe '.implied_vol_put' do
    include_examples 'implied vol returns nil for invalid inputs', :implied_vol_put

    context 'with valid inputs' do
      it 'recovers volatility for standard ATM case' do
        target = described_class.price_put(100, 100, 1, 0.05, 0.2, 0.03)
        approx_equal(described_class.implied_vol_put(100, 100, 1, 0.05, target, 0.03), 0.2, 1e-4)
      end

      it 'recovers volatility for small values' do
        target = described_class.price_put(1, 1, 0.25, 0.01, 0.15, 0)
        approx_equal(described_class.implied_vol_put(1, 1, 0.25, 0.01, target, 0), 0.15, 1e-3)
      end

      it 'recovers volatility for large values' do
        target = described_class.price_put(1000, 900, 3, 0.03, 0.25, 0.02)
        approx_equal(described_class.implied_vol_put(1000, 900, 3, 0.03, target, 0.02), 0.25, 1e-3)
      end

      it 'recovers volatility for long time' do
        target = described_class.price_put(100, 100, 5, 0.04, 0.18, 0.025)
        approx_equal(described_class.implied_vol_put(100, 100, 5, 0.04, target, 0.025), 0.18, 1e-3)
      end

      it 'recovers volatility for negative rate' do
        target = described_class.price_put(100, 100, 1, -0.01, 0.2, 0.03)
        approx_equal(described_class.implied_vol_put(100, 100, 1, -0.01, target, 0.03), 0.2, 1e-3)
      end

      it 'recovers volatility for high vol' do
        target = described_class.price_put(100, 100, 1, 0.05, 1.0, 0.03)
        approx_equal(described_class.implied_vol_put(100, 100, 1, 0.05, target, 0.03), 1.0, 1e-3)
      end

      it 'recovers volatility for low vol' do
        target = described_class.price_put(100, 100, 1, 0.05, 0.01, 0.03)
        approx_equal(described_class.implied_vol_put(100, 100, 1, 0.05, target, 0.03), 0.01, 1e-3)
      end

      it 'recovers volatility for high div' do
        target = described_class.price_put(100, 100, 1, 0.05, 0.2, 0.1)
        approx_equal(described_class.implied_vol_put(100, 100, 1, 0.05, target, 0.1), 0.2, 1e-3)
      end

      it 'recovers volatility for ITM short time' do
        target = described_class.price_put(90, 80, 0.2, 0.06, 0.3, 0.04)
        approx_equal(described_class.implied_vol_put(90, 80, 0.2, 0.06, target, 0.04), 0.3, 1e-3)
      end

      it 'recovers volatility for negative rate ITM' do
        target = described_class.price_put(300, 250, 2, -0.005, 0.22, 0.05)
        approx_equal(described_class.implied_vol_put(300, 250, 2, -0.005, target, 0.05), 0.22, 1e-3)
      end

      it 'handles target above parity' do
        target = 200
        vol = described_class.implied_vol_put(100, 100, 1, 0.05, target, 0.03)
        expect(vol).to be > 1.0
      end

      it 'handles target below 0' do
        target = -1
        vol = described_class.implied_vol_put(100, 100, 1, 0.05, target, 0.03)
        expect(vol).to be > 0
      end
    end
  end

  describe '.d_one' do
    context 'with valid inputs' do
      it 'computes correctly for deep ITM' do
        approx_equal(described_class.d_one(200, 100, 1, 0.05, 0.2, 0.03), 3.6657359027997263)
      end

      it 'computes correctly for small values' do
        approx_equal(described_class.d_one(1, 1, 0.25, 0.01, 0.15, 0), 0.07083333333333333)
      end

      it 'computes correctly for standard ATM' do
        approx_equal(described_class.d_one(100, 100, 1, 0.05, 0.2, 0.03), 0.20000000000000004)
      end

      it 'computes correctly for negative rate' do
        approx_equal(described_class.d_one(100, 100, 1, -0.01, 0.2, 0.03), -0.16000000000000003, 0.061)
      end
    end
  end

  describe '.d_two' do
    context 'with valid inputs' do
      it 'computes correctly for deep ITM' do
        approx_equal(described_class.d_two(200, 100, 1, 0.05, 0.2, 0.03), 3.465735902799726)
      end

      it 'computes correctly for small values' do
        approx_equal(described_class.d_two(1, 1, 0.25, 0.01, 0.15, 0), -0.004166666666666666)
      end

      it 'computes correctly for standard ATM' do
        approx_equal(described_class.d_two(100, 100, 1, 0.05, 0.2, 0.03), 0.0)
      end

      it 'computes correctly for negative rate' do
        approx_equal(described_class.d_two(100, 100, 1, -0.01, 0.2, 0.03), -0.36, 0.07)
      end
    end
  end

  describe '.norm_sdist' do
    it 'computes correctly for z=0' do
      approx_equal(described_class.norm_sdist(0), 0.5)
    end

    it 'computes correctly for z=1' do
      approx_equal(described_class.norm_sdist(1), 0.8413447460685429)
    end

    it 'computes correctly for z=-1' do
      approx_equal(described_class.norm_sdist(-1), 0.15865525393145707)
    end

    it 'computes correctly for z=2' do
      approx_equal(described_class.norm_sdist(2), 0.9772498680518208)
    end

    it 'computes correctly for z=-2' do
      approx_equal(described_class.norm_sdist(-2), 0.022750131948179195)
    end

    it 'computes correctly for z=3' do
      approx_equal(described_class.norm_sdist(3), 0.9986501019683699)
    end

    it 'computes correctly for z=-3' do
      approx_equal(described_class.norm_sdist(-3), 0.0013498980316300933)
    end

    it 'computes correctly for z=4' do
      approx_equal(described_class.norm_sdist(4), 0.9999683287581669)
    end

    it 'computes correctly for z=-4' do
      approx_equal(described_class.norm_sdist(-4), 3.167124183311986e-05)
    end

    it 'computes correctly for z=5' do
      approx_equal(described_class.norm_sdist(5), 0.9999997133484281)
    end

    it 'computes correctly for z=-5' do
      approx_equal(described_class.norm_sdist(-5), 2.866515718791933e-07)
    end

    it 'computes correctly for z=-8' do
      approx_equal(described_class.norm_sdist(-8), 6.22096057427174e-16)
    end

    it 'computes correctly for z=8' do
      approx_equal(described_class.norm_sdist(8), 0.9999999999999993)
    end

    it 'returns 0 for z below min' do
      expect(described_class.norm_sdist(-9)).to eq(0.0)
    end

    it 'returns 1 for z above max' do
      expect(described_class.norm_sdist(9)).to eq(1.0)
    end
  end

  describe '.phi' do
    it 'computes correctly for x=0' do
      approx_equal(described_class.phi(0), 0.3989422804014327)
    end

    it 'computes correctly for x=1' do
      approx_equal(described_class.phi(1), 0.24197072451914337)
    end

    it 'computes correctly for x=-1' do
      approx_equal(described_class.phi(-1), 0.24197072451914337)
    end

    it 'computes correctly for x=2' do
      approx_equal(described_class.phi(2), 0.05399096651318805)
    end

    it 'computes correctly for x=-2' do
      approx_equal(described_class.phi(-2), 0.05399096651318805)
    end

    it 'computes correctly for x=3' do
      approx_equal(described_class.phi(3), 0.004431848411938008)
    end

    it 'computes correctly for x=-3' do
      approx_equal(described_class.phi(-3), 0.004431848411938008)
    end

    it 'computes correctly for x=4' do
      approx_equal(described_class.phi(4), 0.00013383022576488534)
    end

    it 'computes correctly for x=-4' do
      approx_equal(described_class.phi(-4), 0.00013383022576488534)
    end

    it 'computes correctly for x=5' do
      approx_equal(described_class.phi(5), 1.486719514734298e-06)
    end

    it 'computes correctly for x=-5' do
      approx_equal(described_class.phi(-5), 1.486719514734298e-06)
    end

    it 'computes correctly for x=-8' do
      approx_equal(described_class.phi(-8), 5.052271083536893e-15)
    end

    it 'computes correctly for x=8' do
      approx_equal(described_class.phi(8), 5.052271083536893e-15)
    end
  end

  # Additional edge cases
  describe 'edge cases' do
    it 'handles very small time >0' do
      price = described_class.price_call(100, 100, 1e-6, 0.05, 0.2, 0.03)
      expect(price).to be > 0  # Small but positive for ATM
    end

    it 'handles high volatility' do
      delta = described_class.delta_call(100, 100, 1, 0.05, 10, 0.03)
      expect(delta).to be_between(0, 1)
    end

    it 'handles negative interest rate' do
      price = described_class.price_call(100, 100, 1, -0.01, 0.2, 0.03)
      expect(price).to be > 0
    end

    it 'handles high dividend' do
      price = described_class.price_call(100, 100, 1, 0.05, 0.2, 0.1)
      expect(price).to be < 10  # Reasonable bound
    end

    it 'handles very low volatility' do
      price = described_class.price_call(100, 100, 1, 0.05, 0.0001, 0.03)
      expect(price).to be > 0
    end

    it 'handles very high time' do
      price = described_class.price_call(100, 100, 10, 0.05, 0.2, 0.03)
      expect(price).to be > 0
    end

    it 'handles S much larger than K' do
      delta = described_class.delta_call(1000, 10, 1, 0.05, 0.2, 0.03)
      approx_equal(delta, 1, 0.03)
    end

    it 'handles S much smaller than K' do
      delta = described_class.delta_call(10, 1000, 1, 0.05, 0.2, 0.03)
      approx_equal(delta, 0, 0.01)
    end

    it 'handles zero dividend high rate' do
      theta = described_class.theta_call(100, 100, 1, 0.1, 0.2, 0)
      expect(theta).to be < 0
    end

    it 'handles negative dividend (unlikely but math)' do
      vega = described_class.vega(100, 100, 1, 0.05, 0.2, -0.01)
      expect(vega).to be > 0
    end

    it 'implied vol for price exactly intrinsic' do
      intrinsic = [100 - 100 * Math.exp(-0.05 * 1), 0].max
      vol = described_class.implied_vol_call(100, 100, 1, 0.05, intrinsic, 0.03)
      expect(vol).to be > 0
    end

    it 'gamma near zero for deep ITM' do
      gamma = described_class.gamma(1000, 10, 1, 0.05, 0.2, 0.03)
      expect(gamma).to be < 1e-5
    end

    it 'vega near zero for deep OTM' do
      vega = described_class.vega(10, 1000, 1, 0.05, 0.2, 0.03)
      expect(vega).to be < 1e-5
    end

    it 'theta positive for some cases' do
      theta = described_class.theta_put(80, 100, 2, 0.1, 0.1, 0.05)
      expect(theta).to be > 0
    end
  end
end