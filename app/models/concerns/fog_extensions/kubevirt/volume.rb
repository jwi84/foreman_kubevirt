module FogExtensions
  module Kubevirt
    module Volume
      extend ActiveSupport::Concern
      def bootable
        !boot_order.nil?
      end

      def id
        name
      end

      # Requested access and volume modes of a new claim. For an existing volume they come from its claim.
      def access_mode
        attributes[:access_mode] || (pvc.access_modes&.first if pvc.respond_to?(:access_modes))
      end

      def access_mode=(value)
        attributes[:access_mode] = value
      end

      def volume_mode
        attributes[:volume_mode] || (pvc.volume_mode if pvc.respond_to?(:volume_mode))
      end

      def volume_mode=(value)
        attributes[:volume_mode] = value
      end
    end
  end
end
