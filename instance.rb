require 'ipaddress'
require_relative 'inspect'
require_relative 'user_access'

class Instance
  include Inspect

  attr_reader :subnet, :name, :os, :ip_address, :ip_address_dynamic, :internet_accessible, :roles

  NAME_KEY = 'Name'
  OS_KEY = 'OS'
  IP_ADDRESS_KEY = 'IP_Address'
  IP_ADDRESS_DYNAMIC_KEY = 'IP_Address_Dynamic'
  INTERNET_ACCESSIBLE_KEY = 'Internet_Accessible'
  ROLES_KEY = 'Roles'

  def initialize subnet, hash
    self.subnet = subnet
    self.name = hash[NAME_KEY]
    self.os = hash[OS_KEY]
    self.ip_address_dynamic = hash[IP_ADDRESS_DYNAMIC_KEY] || false
    self.internet_accessible = hash[INTERNET_ACCESSIBLE_KEY] || false
    self.ip_address = hash[IP_ADDRESS_KEY]
    role_names = hash[ROLES_KEY] || []
    self.roles = role_names.map do |role_name|
      role = scenario.roles.find{ |role| role.name == role_name }
      raise "Instance #{name} Role #{role_name} does not exist" if role.nil?
      role
    end
  end

  def to_hash
    {
      NAME_KEY => name,
      OS_KEY => os,
      IP_ADDRESS_DYNAMIC_KEY => ip_address_dynamic,
      INTERNET_ACCESSIBLE_KEY => internet_accessible,
      IP_ADDRESS_KEY => ip_address.to_s,
      ROLES_KEY => roles.map{ |role| role.name }
    }
  end

  def recipes
    roles.flat_map{ |role| role.recipes }
  end

  def packages
    roles.flat_map{ |role| role.recipe }
  end

  def cloud
    subnet.cloud
  end

  def scenario
    cloud.scenario
  end

  def access
    # since instances are members of groups (that is the access relationship is owned by group),
    # we must find references to this instance in the groups.
    scenario.groups.map{ |group| group.access_for self }.compact
  end

  def groups
    access.map{ |a| a.group }
  end

  def users
    groups.flat_map{ |group| group.users }.map{ |user| UserAccess.new user, (user.group.access_for self) }
  end

  private

  attr_writer :subnet, :ip_address_dynamic, :internet_accessible

  def name= name
    raise "#{self.class.name} #{NAME_KEY} '#{name}'  must only contain alphanumeric characters and underscores" if /\W/.match name
    @name = name
  end

  SUPPORTED_OS = 'ubuntu', 'nat'

  def os= os
    raise "Instance #{OS_KEY} #{os} is not supported." unless SUPPORTED_OS.include? os
    @os = os
  end

  def ip_address= ip
    ip = IPAddress.parse ip
    raise "Instance #{IP_ADDRESS_KEY} #{ip} must be IPv4" unless ip.ipv4?
    raise "Instance #{IP_ADDRESS_KEY} #{ip.to_string} must be a single host, not a block" unless ip.prefix == 32
    raise "Instance #{IP_ADDRESS_KEY} #{ip} is not contained in Subnet #{Subnet::CIDR_BLOCK_KEY} #{subnet.cidr_block.to_string}" unless subnet.cidr_block.include? ip
    @ip_address = ip
  end

  def roles= roles
    raise "Instance #{ROLES_KEY} must not be empty" if roles.blank?
    @roles = roles
  end
end

