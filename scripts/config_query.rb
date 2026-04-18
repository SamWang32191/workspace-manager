#!/usr/bin/env ruby
require 'yaml'

def invalid_config(message)
  abort "Invalid config: #{message}"
end

def require_mapping(value, name)
  return value if value.is_a?(Hash)

  invalid_config("#{name} must be a mapping")
end

def require_list(value, name)
  return value if value.is_a?(Array)

  invalid_config("#{name} must be a list")
end

def require_string(value, name)
  return value if value.is_a?(String)

  invalid_config("#{name} must be a string")
end

config_path = ARGV.shift or abort 'missing config path'
command = ARGV.shift or abort 'missing command'

config = YAML.load_file(config_path) || {}
config = require_mapping(config, 'root config')

case command
when 'list-profiles'
  profiles = require_mapping(config.fetch('profiles'), 'profiles')
  puts profiles.keys.sort
when 'profile-repos'
  profile = ARGV.shift or abort 'missing profile'
  profiles = require_mapping(config.fetch('profiles'), 'profiles')
  unless profiles.key?(profile)
    warn "unknown profile: #{profile}"
    exit 3
  end

  repos = profiles[profile]
  repos = require_list(repos, "profile [#{profile}] repos")
  puts repos
when 'base-repo-dir'
  puts require_string(config['base_repo_dir'], 'base_repo_dir')
when 'workspace-root'
  puts require_string(config['workspace_root'], 'workspace_root')
else
  abort "unknown command: #{command}"
end
