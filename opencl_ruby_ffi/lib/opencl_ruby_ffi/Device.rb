using OpenCLRefinements if RUBY_VERSION.scan(/\d+/).collect(&:to_i).first >= 2
module OpenCL

  # Splits a Device in serveral sub-devices
  #
  # ==== Attributes
  # 
  # * +in_device+ - the Device to be partitioned
  # * +properties+ - an Array of cl_device_partition_property
  #
  # ==== Returns
  #
  # an Array of Device
  def self.create_sub_devices( in_device, properties )
    error_check(INVALID_OPERATION) if in_device.platform.version_number < 1.2
    props = MemoryPointer::new( :cl_device_partition_property, properties.length + 1 )
    properties.each_with_index { |e,i|
      props[i].write_cl_device_partition_property(e)
    }
    props[properties.length].write_cl_device_partition_property(0)
    device_number_ptr = MemoryPointer::new( :cl_uint )
    error = clCreateSubDevices( in_device, props, 0, nil, device_number_ptr )
    error_check(error)
    device_number = device_number_ptr.read_cl_uint
    devices_ptr = MemoryPointer::new( Device, device_number )
    error = clCreateSubDevices( in_device, props, device_number, devices_ptr, nil )
    error_check(error)
    devices_ptr.get_array_of_pointer(0, device_number).collect { |device_ptr|
        Device::new(device_ptr, false)
    }
  end

  def self.get_device_and_host_timer( device )
    error_check(INVALID_OPERATION) if device.platform.version_number < 2.1
    device_timestamp_p = MemoryPointer::new( :cl_ulong )
    host_timestamp_p = MemoryPointer::new( :cl_ulong )
    error = clGetDeviceAndHostTimer( device, device_timestamp_p, host_timestamp_p)
    error_check(error)
    return [ device_timestamp_p.read_cl_ulong, host_timestamp_p.read_cl_ulong ]
  end

  def self.get_device_and_host_timer( device )
    error_check(INVALID_OPERATION) if device.platform.version_number < 2.1
    host_timestamp_p = MemoryPointer::new( :cl_ulong )
    error = clGetHostTimer( device, host_timestamp_p)
    error_check(error)
    return host_timestamp_p.read_cl_ulong
  end

  # Maps the cl_device_id object of OpenCL
  class Device
    include InnerInterface

    class << self
      include InnerGenerator
    end

    def inspect
      return "#<#{self.class.name}: #{name} (#{pointer.to_i})>"
    end

    #:stopdoc:
    DRIVER_VERSION = 0x102D
    #:startdoc:

    # Returns an Array of String corresponding to the Device extensions
    def extensions
      extensions_size = MemoryPointer::new( :size_t )
      error = OpenCL.clGetDeviceInfo( self, EXTENSIONS, 0, nil, extensions_size)
      error_check(error)
      ext = MemoryPointer::new( extensions_size.read_size_t )
      error = OpenCL.clGetDeviceInfo( self, EXTENSIONS, extensions_size.read_size_t, ext, nil)
      error_check(error)
      ext_string = ext.read_string
      return ext_string.split(" ")
    end

    # Returns an Array of String corresponding to the Device built in kernel names
    def built_in_kernels
      built_in_kernels_size = MemoryPointer::new( :size_t )
      error = OpenCL.clGetDeviceInfo( self, BUILT_IN_KERNELS, 0, nil, built_in_kernels_size)
      error_check(error)
      ker = MemoryPointer::new( built_in_kernels_size.read_size_t )
      error = OpenCL.clGetDeviceInfo( self, BUILT_IN_KERNELS, built_in_kernels_size.read_size_t, ker, nil)
      error_check(error)
      ker_string = ker.read_string
      return ker_string.split(";")
    end

    # Return an Array of String corresponding to the SPIR versions supported by the device
    def spir_versions
      spir_versions_size = MemoryPointer::new( :size_t )
      error = OpenCL.clGetDeviceInfo( self, SPIR_VERSIONS, 0, nil, spir_versions_size)
      error_check(error)
      vers = MemoryPointer::new( spir_versions_size.read_size_t )
      error = OpenCL.clGetDeviceInfo( self, SPIR_VERSIONS, spir_versions_size.read_size_t, vers, nil)
      error_check(error)
      vers_string = vers.read_string
      return vers_string.split(" ")
    end

    def spir_versions_number
      vers_strings = spir_versions
      return vers_strings.collect { |s| s.scan(/(\d+\.\d+)/).first.first.to_f }
    end

    def il_version_number
      return il_version.scan(/(\d+\.\d+)/).first.first.to_f
    end

    %w( BUILT_IN_KERNELS DRIVER_VERSION VERSION VENDOR PROFILE OPENCL_C_VERSION NAME IL_VERSION ).each { |prop|
      eval get_info("Device", :string, prop)
    }

    # returs a floating point number corresponding to the OpenCL C version of the Device
    def opencl_c_version_number
      ver = self.opencl_c_version
      n = ver.scan(/OpenCL C (\d+\.\d+)/)
      return n.first.first.to_f
    end

    # returs a floating point number corresponding to the OpenCL version of the Device
    def version_number
      ver = self.version
      n = ver.scan(/OpenCL (\d+\.\d+)/)
      return n.first.first.to_f
    end

    %w( MAX_MEM_ALLOC_SIZE MAX_CONSTANT_BUFFER_SIZE LOCAL_MEM_SIZE GLOBAL_MEM_CACHE_SIZE GLOBAL_MEM_SIZE ).each { |prop|
      eval get_info("Device", :cl_ulong, prop)
    }

    %w( IMAGE_PITCH_ALIGNMENT IMAGE_BASE_ADDRESS_ALIGNMENT REFERENCE_COUNT PARTITION_MAX_SUB_DEVICES VENDOR_ID PREFERRED_VECTOR_WIDTH_HALF PREFERRED_VECTOR_WIDTH_CHAR PREFERRED_VECTOR_WIDTH_SHORT PREFERRED_VECTOR_WIDTH_INT PREFERRED_VECTOR_WIDTH_LONG PREFERRED_VECTOR_WIDTH_FLOAT PREFERRED_VECTOR_WIDTH_DOUBLE NATIVE_VECTOR_WIDTH_CHAR NATIVE_VECTOR_WIDTH_SHORT NATIVE_VECTOR_WIDTH_INT NATIVE_VECTOR_WIDTH_LONG NATIVE_VECTOR_WIDTH_FLOAT NATIVE_VECTOR_WIDTH_DOUBLE NATIVE_VECTOR_WIDTH_HALF MIN_DATA_TYPE_ALIGN_SIZE MEM_BASE_ADDR_ALIGN MAX_WRITE_IMAGE_ARGS MAX_READ_WRITE_IMAGE_ARGS MAX_WORK_ITEM_DIMENSIONS MAX_SAMPLERS MAX_READ_IMAGE_ARGS MAX_CONSTANT_ARGS MAX_COMPUTE_UNITS MAX_CLOCK_FREQUENCY ADDRESS_BITS GLOBAL_MEM_CACHELINE_SIZE QUEUE_ON_DEVICE_PREFERRED_SIZE QUEUE_ON_DEVICE_MAX_SIZE MAX_ON_DEVICE_QUEUES MAX_ON_DEVICE_EVENTS MAX_PIPE_ARGS PIPE_MAX_ACTIVE_RESERVATIONS PIPE_MAX_PACKET_SIZE PREFERRED_PLATFORM_ATOMIC_ALIGNMENT PREFERRED_GLOBAL_ATOMIC_ALIGNMENT PREFERRED_LOCAL_ATOMIC_ALIGNMENT MAX_NUM_SUB_GROUPS ).each { |prop|
      eval get_info("Device", :cl_uint, prop)
    }

    %w( PRINTF_BUFFER_SIZE IMAGE_MAX_BUFFER_SIZE IMAGE_MAX_ARRAY_SIZE PROFILING_TIMER_RESOLUTION MAX_WORK_GROUP_SIZE MAX_PARAMETER_SIZE IMAGE2D_MAX_WIDTH IMAGE2D_MAX_HEIGHT IMAGE3D_MAX_WIDTH IMAGE3D_MAX_HEIGHT IMAGE3D_MAX_DEPTH MAX_GLOBAL_VARIABLE_SIZE GLOBAL_VARIABLE_PREFERRED_TOTAL_SIZE ).each { |prop|
      eval get_info("Device", :size_t, prop)
    }

    %w( PREFERRED_INTEROP_USER_SYNC LINKER_AVAILABLE IMAGE_SUPPORT HOST_UNIFIED_MEMORY COMPILER_AVAILABLE AVAILABLE ENDIAN_LITTLE ERROR_CORRECTION_SUPPORT SUB_GROUP_INDEPENDENT_FORWARD_PROGRESS ).each { |prop|
      eval get_info("Device", :cl_bool, prop)
    }

    %w( SINGLE_FP_CONFIG HALF_FP_CONFIG DOUBLE_FP_CONFIG ).each { |prop|
      eval get_info("Device", :cl_device_fp_config, prop)
    }

    ##
    # :method: execution_capabilities()
    # Returns an ExecCpabilities representing the execution capabilities corresponding to the Device
    eval get_info("Device", :cl_device_exec_capabilities, "EXECUTION_CAPABILITIES")

    ##
    # :method: global_mem_cache_type()
    # Returns a MemCacheType representing the type of the global cache memory on the Device
    eval get_info("Device", :cl_device_mem_cache_type, "GLOBAL_MEM_CACHE_TYPE")

    ##
    # :method: local_mem_type()
    # Returns a LocalMemType rpresenting the type of the local memory on the Device
    eval get_info("Device", :cl_device_local_mem_type, "LOCAL_MEM_TYPE")

    ##
    # :method: queue_properties()
    # Returns a CommandQueue::Properties representing the properties supported by a CommandQueue targetting the Device
    eval get_info("Device", :cl_command_queue_properties, "QUEUE_PROPERTIES")

    ##
    # :method: queue_on_device_properties()
    # Returns a CommandQueue::Properties representing the properties supported by a CommandQueue on the Device
    eval get_info("Device", :cl_command_queue_properties, "QUEUE_ON_DEVICE_PROPERTIES")

    ##
    # :method: queue_on_host_properties()
    # Returns a CommandQueue::Properties representing the properties supported by a CommandQueue targetting the Device
    eval get_info("Device", :cl_command_queue_properties, "QUEUE_ON_HOST_PROPERTIES")

    ##
    # :method: type()
    # Returns a Device::Type representing the type of the Device
    eval get_info("Device", :cl_device_type, "TYPE")

    ##
    # :method: partition_affinity_domain()
    # Returns an AffinityDomain representing the list of supported affinity domains for partitioning the Device using OpenCL::Device::PARTITION_BY_AFFINITY_DOMAIN
    eval get_info("Device", :cl_device_affinity_domain, "PARTITION_AFFINITY_DOMAIN")

    ##
    # :method: max_work_item_sizes()
    # Maximum number of work-items that can be specified in each dimension of the work-group to clEnqueueNDRangeKernel for the Device
    eval get_info_array("Device", :size_t, "MAX_WORK_ITEM_SIZES")

    ##
    # :method: partition_properties()
    # Returns the list of partition types supported by the Device
    def partition_properties
      ptr1 = MemoryPointer::new( :size_t, 1)
      error = OpenCL.clGetDeviceInfo(self, PARTITION_PROPERTIES, 0, nil, ptr1)
      error_check(error)
      ptr2 = MemoryPointer::new( ptr1.read_size_t )
      error = OpenCL.clGetDeviceInfo(self, PARTITION_PROPERTIES, ptr1.read_size_t, ptr2, nil)
      error_check(error)
      arr = ptr2.get_array_of_cl_device_partition_property(0, ptr1.read_size_t/ OpenCL.find_type(:cl_device_partition_property).size)
      arr.reject! { |e| e.null? }
      return arr.collect { |e| Partition::new(e.to_i) }
    end

    ##
    # :method: svm_capabilities()
    # Returns an SVMCapabilities representing the the SVM capabilities corresponding to the device
    eval get_info_array("Device", :cl_device_svm_capabilities, "SVM_CAPABILITIES")

    # Return an Array of partition properties names representing the partition type supported by the device
    def partition_properties_names
      self.partition_properties.collect { |p| p.name }
    end

    ##
    # :method: partition_type()
    # Returns a list of :cl_device_partition_property used to create the Device
    def partition_type
      ptr1 = MemoryPointer::new( :size_t, 1)
      error = OpenCL.clGetDeviceInfo(self, PARTITION_TYPE, 0, nil, ptr1)
      error_check(error)
      ptr2 = MemoryPointer::new( ptr1.read_size_t )
      error = OpenCL.clGetDeviceInfo(self, PARTITION_TYPE, ptr1.read_size_t, ptr2, nil)
      error_check(error)
      arr = ptr2.get_array_of_cl_device_partition_property(0, ptr1.read_size_t/ OpenCL.find_type(:cl_device_partition_property).size)
      if arr.first.to_i == Partition::BY_NAMES_EXT then
        arr_2 = []
        arr_2.push(Partition::new(arr.first.to_i))
        i = 1
        return arr_2 if arr.length <= i
        while arr[i].to_i - (0x1 << Pointer.size * 8) != Partition::BY_NAMES_LIST_END_EXT do
          arr_2[i] = arr[i].to_i
          i += 1
          return arr_2 if arr.length <= i
        end
        arr_2[i] = Partition::new(Partition::BY_NAMES_LIST_END_EXT)
        arr_2[i+1] = 0
        return arr_2
      else
        return arr.collect { |e| Partition::new(e.to_i) }
      end
    end
    #eval get_info_array("Device", :cl_device_partition_property, "PARTITION_TYPE")

    # Returns the Platform the Device belongs to
    def platform
      ptr = MemoryPointer::new( OpenCL::Platform )
      error = OpenCL.clGetDeviceInfo(self, PLATFORM, OpenCL::Platform.size, ptr, nil)
      error_check(error)
      return OpenCL::Platform::new(ptr.read_pointer)
    end

    # Returns the parent Device if it exists
    def parent_device
      ptr = MemoryPointer::new( Device )
      error = OpenCL.clGetDeviceInfo(self, PARENT_DEVICE, Device.size, ptr, nil)
      error_check(error)
      return nil if ptr.null?
      return Device::new(ptr.read_pointer)
    end

    # Partitions the Device in serveral sub-devices
    #
    # ==== Attributes
    # 
    # * +properties+ - an Array of :cl_device_partition_property
    #
    # ==== Returns
    #
    # an Array of Device
    def create_sub_devices( properties )
      return OpenCL.create_sub_devices( self, properties )
    end

    # Partitions the Device in serveral sub-devices by affinity domain
    #
    # ==== Attributes
    # 
    # * +affinity_domain+ - the :cl_device_partition_property specifying the target affinity domain
    #
    # ==== Returns
    #
    # an Array of Device
    def partition_by_affinity_domain( affinity_domain = AFFINITY_DOMAIN_NEXT_PARTITIONABLE )
      return OpenCL.create_sub_devices( self,  [ PARTITION_BY_AFFINITY_DOMAIN, affinity_domain ] )
    end

    # Partitions the Device in serveral sub-devices containing compute_unit_number compute units
    #
    # ==== Attributes
    # 
    # * +compute_unit_number+ - the number of compute units in each sub-device
    #
    # ==== Returns
    #
    # an Array of Device
    def partition_equally( compute_unit_number = 1 )
      return OpenCL.create_sub_devices( self,  [ PARTITION_EQUALLY, compute_unit_number ] )
    end

    # Partitions the Device in serveral sub-devices each containing a specific number of compute units
    #
    # ==== Attributes
    # 
    # * +compute_unit_number_list+ - an Array of compute unit number
    #
    # ==== Returns
    #
    # an Array of Device
    def partition_by_count( compute_unit_number_list = [1] )
      return OpenCL.create_sub_devices( self,  [ PARTITION_BY_COUNTS] + compute_unit_number_list + [ PARTITION_BY_COUNTS_LIST_END ] )
    end

    def get_device_and_host_timer
      return OpenCL.get_device_and_host_timer( self )
    end

    def get_host_timer
      return OpenCL.get_host_timer( self )
    end

  end

end
