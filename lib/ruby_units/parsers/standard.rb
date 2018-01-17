require 'parslet'
require_relative '../transformers/standard'

module RubyUnits
  module Parsers
    # This parser is designed to handle SI and Imperial unit systems.  It will
    # also detect and properly parse several irregular unit forms (like '6 foot
    # 4' and '19 lbs, 4 oz').
    class Standard < ::Parslet::Parser
      # Checks for all defined unit names (excluding prefixes). The names are
      # sorted longest first and checked in that order so more specific ones
      # will be honored first.  Does not consider unit names longer than the
      # string that is being parsed because it cannot match.
      # @param [Integer] max_length of string to parse.
      # @return [Parslet::Parser]
      def unit_names(max_length:)
        names = RubyUnits::Unit.sorted_unit_names
        (names.select { |name| name.length <= max_length }.map { |name| str(name) }.reduce(:|) || str('1')).as(:name)
      end

      # Checks agains a list of all defined prefixes. Prefixes are sorted
      # longest first so that the most specific ones are honored first. Does not
      # consider prefixes longer than the  string being parsed because it cannot
      # match.
      # @param [Integer] max_length of string to parse.
      # @return [Parslet::Parser]
      def prefixes(max_length:)
        names = RubyUnits::Unit.sorted_prefix_names
        (names.select { |name| name.length <= max_length }.map { |name| str(name) }.reduce(:|) || str('1')).as(:prefix)
      end

      rule(:complex) { ((rational | decimal | integer).as(:real) >> (rational | decimal | integer).as(:imaginary) >> str('i')).as(:complex) }
      rule(:decimal) { (sign? >> unsigned_integer >> str('.') >> digits).as(:decimal) }
      rule(:digit) { match['0-9'] }
      rule(:digits?) { digits.maybe }
      rule(:digits) { digit.repeat(1) }
      rule(:div_operator) { space? >> str('/') >> space? }
      rule(:feet_inches) { (rational | decimal | integer).as(:ft) >> space? >> (str('feet') | str('foot') | str('ft') | str("'")) >> str(',').maybe >> space? >> (rational | decimal | integer).as(:in) >> space? >> (str('inches') | str('inch') | str('in') | str('"')).maybe }
      rule(:integer_with_separators) { (sign? >> non_zero_digit >> digit.repeat(0, 2) >> (separators >> digit.repeat(3, 3)).repeat(1)) }
      rule(:integer) { (sign? >> unsigned_integer).as(:integer) }
      rule(:irregular_forms) { times | feet_inches.maybe | lbs_oz.maybe | stone.maybe }
      rule(:lbs_oz) { (rational | decimal | integer).as(:lbs) >> space? >> (str('pounds') | str('pound') | str('lbs') | str('lb')) >> str(',').maybe >> space? >> (rational | decimal | integer).as(:oz) >> space? >> (str('ounces') | str('ounce') | str('oz')) }
      rule(:mixed_fraction) { (integer.as(:whole) >> (space | str('-')) >> rational.as(:fraction)).as(:mixed_fraction) }
      rule(:mult_operator) { ((space? >> str('*') >> space?) | (space? >> str('x') >> space?) | space).as(:multiply) }
      rule(:non_zero_digit) { match['1-9'] }
      rule(:operator) { (div_operator | mult_operator).as(:operator) }
      rule(:power) { str('^') | str('**') }
      rule(:prefix?) { prefix.maybe }
      rule(:prefix) { dynamic { |source, _context| prefixes(max_length: source.chars_left) } }
      rule(:rational) { ((decimal | integer).as(:numerator) >> str('/') >> (decimal | integer).as(:denominator)).as(:rational) }
      rule(:scalar?) { scalar.maybe }
      rule(:scalar) { (mixed_fraction | complex | rational | scientific | decimal | integer).as(:scalar) }
      rule(:scientific) { ((decimal | integer).as(:mantissa) >> match['eE'] >> (sign? >> digits).as(:exponent)).as(:scientific) }
      rule(:separators) { match[',_'] }
      rule(:sign?) { sign.maybe }
      rule(:sign) { match['+-'] }
      rule(:space?) { space.maybe }
      rule(:space) { str(' ') }
      rule(:stone) { (rational | decimal | integer).as(:stone) >> space? >> (str('stones') | str('stone') | str('st')) >> str(',').maybe >> space? >> (rational | decimal | integer).as(:lbs) >> space? >> (str('pounds') | str('pound') | str('lbs') | str('lb')).maybe }
      rule(:times) { (zero | digits).as(:hours) >> str(':') >> (match['0-5'] >> digit).as(:minutes) >> (str(':') >> (match['0-5'] >> digit).as(:seconds)).maybe >> (str(',') >> unsigned_integer.as(:microseconds)).maybe }
      rule(:unit_atom) { (scalar? >> space? >> (str('1') | unit_part | (prefix >> unit_part)).maybe >> (power >> (rational | decimal | integer).as(:power)).maybe).as(:unit) }
      rule(:unit_part?) { unit_part.maybe }
      rule(:name) { dynamic { |source, _context| unit_names(max_length: source.chars_left) } }
      rule(:unit_part) { str('<').maybe >> name >> str('>').maybe >> match['\w'].absent? }
      rule(:unit) { irregular_forms | infix_expression(unit_atom, [power, 3, :left], [mult_operator, 2, :left], [div_operator, 1, :left]) }
      rule(:unsigned_integer) { zero | integer_with_separators | non_zero_digit >> digits? }
      rule(:zero) { str('0') }

      root(:unit)
    end
  end
end
