# Author Dan Tylenda-Emmons and Intrinio
# Since Feb 13, 2011
# Based on Black-Scholes forumla for pricing options

module OptionsCalculations
  class Calculator
    class << self
      # used for min/max normal distribution
      MIN_Z_SCORE, MAX_Z_SCORE = -8.0, +8.0

      # used for implied vol
      VOL_TOLERANCE = 1e-10
      MAX_ITER = 50

      ROOT_2_PI = Math.sqrt(2.0 * Math::PI)

      include Math

      # Checks if inputs are valid; returns true if valid, false otherwise
      def valid_inputs?(underlying, strike, time, sigma)
        underlying > 0.0 && strike > 0.0 && time > 0.0 && sigma > 0.0
      end

      # computes the call price sensitivity to a change in underlying price
      def delta_call( underlying, strike, time, interest, sigma, dividend )
        return nil unless valid_inputs?(underlying, strike, time, sigma)
        d1 = d_one( underlying, strike, time, interest, sigma, dividend )
        exp(-dividend * time) * norm_sdist( d1 )
      end

      # computes the put price sensitivity to a change in underlying price
      def delta_put( underlying, strike, time, interest, sigma, dividend )
        return nil unless valid_inputs?(underlying, strike, time, sigma)
        d1 = d_one( underlying, strike, time, interest, sigma, dividend )
        exp(-dividend * time) * ( norm_sdist( d1 ) - 1 )
      end

      # computes the option price sensitivity to a change in delta
      def gamma( underlying, strike, time, interest, sigma, dividend )
        return nil unless valid_inputs?(underlying, strike, time, sigma)
        d1 = d_one( underlying, strike, time, interest, sigma, dividend )
        exp(-dividend * time) * phi( d1 ) / ( underlying * sigma * sqrt(time) )
      end

      # computes the call price sensitivity to a change in time
      def theta_call( underlying, strike, time, interest, sigma, dividend )
        return nil unless valid_inputs?(underlying, strike, time, sigma)
        d1 = d_one( underlying, strike, time, interest, sigma, dividend )
        d2 = d_two( underlying, strike, time, interest, sigma, dividend )
        exp_qt = exp(-dividend * time)
        exp_rt = exp(-interest * time)
        term1 = exp_qt * underlying * phi( d1 ) * sigma / ( 2 * sqrt(time) )
        term2 = interest * strike * exp_rt * norm_sdist( d2 )
        term3 = dividend * underlying * exp_qt * norm_sdist( d1 )
        ( - term1 - term2 + term3 ) / 365.25
      end

      # computes the put price sensitivity to a change in time
      def theta_put( underlying, strike, time, interest, sigma, dividend )
        return nil unless valid_inputs?(underlying, strike, time, sigma)
        d1 = d_one( underlying, strike, time, interest, sigma, dividend )
        d2 = d_two( underlying, strike, time, interest, sigma, dividend )
        exp_qt = exp(-dividend * time)
        exp_rt = exp(-interest * time)
        term1 = exp_qt * underlying * phi( d1 ) * sigma / ( 2 * sqrt(time) )
        term2 = interest * strike * exp_rt * (1.0 - norm_sdist( d2 ))
        term3 = dividend * underlying * exp_qt * (1.0 - norm_sdist( d1 ))
        ( - term1 + term2 - term3 ) / 365.25
      end

      # computes the option price sensitivity to a change in volatility
      def vega( underlying, strike, time, interest, sigma, dividend )
        return nil unless valid_inputs?(underlying, strike, time, sigma)
        d1 = d_one( underlying, strike, time, interest, sigma, dividend )
        0.01 * underlying * exp(-dividend * time) * sqrt(time) * phi(d1)
      end

      # computes the fair value of the call based on the knowns and assumed volatility (sigma)
      def price_call( underlying, strike, time, interest, sigma, dividend )
        return nil unless valid_inputs?(underlying, strike, time, sigma)
        d1 = d_one( underlying, strike, time, interest, sigma, dividend )
        discounted_underlying = exp(-1.0 * dividend * time) * underlying
        probability_weighted_value_of_being_exercised = discounted_underlying * norm_sdist( d1 )

        d2 = d1 - ( sigma * sqrt(time) )
        discounted_strike = exp(-1.0 * interest * time) * strike
        probability_weighted_value_of_discounted_strike = discounted_strike * norm_sdist( d2 )

        expected_value = probability_weighted_value_of_being_exercised - probability_weighted_value_of_discounted_strike
      end

      # computes the fair value of the put based on the knowns and assumed volatility (sigma)
      def price_put( underlying, strike, time, interest, sigma, dividend )
        return nil unless valid_inputs?(underlying, strike, time, sigma)
        d2 = d_two( underlying, strike, time, interest, sigma, dividend )
        discounted_strike = strike * exp(-1.0 * interest * time)
        probabiltity_weighted_value_of_discounted_strike = discounted_strike * norm_sdist( -1.0 * d2 )

        d1 = d2 + ( sigma * sqrt(time) )
        discounted_underlying = underlying * exp(-1.0 * dividend * time)
        probability_weighted_value_of_being_exercised = discounted_underlying * norm_sdist( -1.0 * d1 )

        expected_value = probabiltity_weighted_value_of_discounted_strike - probability_weighted_value_of_being_exercised
      end

      # finds the implied volatility based on the target_price passed in.
      def implied_vol_call( underlying, strike, time, interest, target_price, dividend )
        return nil unless valid_inputs?(underlying, strike, time, 0.1) # Dummy sigma for validation
        forward = underlying * exp( (interest - dividend) * time )
        m = forward / strike
        sigma = sqrt( 2.0 * log(m).abs / time )
        sigma = 0.3 if sigma.nan? || sigma <= 0.0
        tol = VOL_TOLERANCE
        max_iter = MAX_ITER
        iter = 0
        while iter < max_iter
          price = price_call( underlying, strike, time, interest, sigma, dividend )
          diff = price - target_price
          break if diff.abs < tol
          d1 = d_one( underlying, strike, time, interest, sigma, dividend )
          vega = underlying * exp(-dividend * time) * sqrt(time) * phi(d1)
          break if vega.abs < 1e-10
          sigma -= diff / vega
          sigma = 0.0001 if sigma <= 0.0
          iter += 1
        end
        sigma
      end

      # finds the implied volatility based on the target_price passed in.
      def implied_vol_put( underlying, strike, time, interest, target_price, dividend )
        return nil unless valid_inputs?(underlying, strike, time, 0.1) # Dummy sigma for validation
        forward = underlying * exp( (interest - dividend) * time )
        m = forward / strike
        sigma = sqrt( 2.0 * log(m).abs / time )
        sigma = 0.3 if sigma.nan? || sigma <= 0.0
        tol = VOL_TOLERANCE
        max_iter = MAX_ITER
        iter = 0
        while iter < max_iter
          price = price_put( underlying, strike, time, interest, sigma, dividend )
          diff = price - target_price
          break if diff.abs < tol
          d1 = d_one( underlying, strike, time, interest, sigma, dividend )
          vega = underlying * exp(-dividend * time) * sqrt(time) * phi(d1)
          break if vega.abs < 1e-10
          sigma -= diff / vega
          sigma = 0.0001 if sigma <= 0.0
          iter += 1
        end
        sigma
      end

      # probability of being exercised at maturity (must be greater than d2 by (sigma*sqrt(time)) if exercised)
      def d_one( underlying, strike, time, interest, sigma, dividend )
        numerator = ( log(underlying / strike) + (interest - dividend + 0.5 * sigma ** 2.0 ) * time)
        denominator = ( sigma * sqrt(time) )
        numerator / denominator
      end

      # probability of underlying reaching the strike price (must be smaller than d1 by (sigma*sqrt(time)) if exercised.
      def d_two( underlying, strike, time, interest, sigma, dividend )
        d_one( underlying, strike, time, interest, sigma, dividend ) - ( sigma * sqrt(time) )
      end

      # Normal Standard Distribution
      def norm_sdist( z )
        return 0.0 if z < MIN_Z_SCORE
        return 1.0 if z > MAX_Z_SCORE
        abs_z = z.abs
        if abs_z < 1.5
          sum = 0.0
          term = abs_z
          i = 3.0
          while sum + term != sum
            sum += term
            term *= abs_z * abs_z / i
            i += 2.0
          end
          pdf = exp(-0.5 * abs_z * abs_z) / ROOT_2_PI
          half = pdf * sum
          z >= 0.0 ? 0.5 + half : 0.5 - half
        else
          is_negative = z < 0.0
          z = abs_z if is_negative
          t = 1.0 / (1.0 + 0.2316419 * z)
          poly = t * (0.319381530 + t * (-0.356563782 + t * (1.781477937 + t * (-1.821255978 + t * 1.330274429))))
          pdf = exp(-0.5 * z * z) / ROOT_2_PI
          tail = pdf * poly
          is_negative ? tail : 1.0 - tail
        end
      end

      # Standard Gaussian pdf
      def phi(x)
        exp(-0.5 * x * x) / ROOT_2_PI
      end

    end
  end
end