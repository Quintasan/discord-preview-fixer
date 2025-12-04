# frozen_string_literal: true

class Service
  def self.fix_link(_uri)
    raise ArgumentError, 'HOST_REGEX constant must be defined in subclasses' unless const_defined?(:HOST_REGEX)

    raise NoMethodError, 'Subclasses must implement the fix_link method'
  end
end
