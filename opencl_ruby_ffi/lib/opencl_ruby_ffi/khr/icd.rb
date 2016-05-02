require 'opencl_ruby_ffi'
using OpenCLRefinements if RUBY_VERSION.scan(/\d+/).collect(&:to_i).first >= 2

module OpenCL

  PLATFORM_NOT_FOUND_KHR = -1001

  PLATFORM_ICD_SUFFIX_KHR = 0x0920

  class Error

    eval error_class_constructor( :PLATFORM_NOT_FOUND_KHR, :PlatformNotFoundKHR )

  end

  class Platform
    ICD_SUFFIX_KHR = 0x0920
  end

  module KHRICDPlatform
    class << self
      include InnerGenerator
    end

    eval get_info("Platform", :string, "ICD_SUFFIX_KHR", "Platform::")

  end

  Platform::Extensions[:cl_khr_icd] = [ KHRICDPlatform, "extensions.include?(\"cl_khr_icd\")" ]

end