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
  repos = profiles[profile]
  if repos.nil?
    warn "unknown profile: #{profile}"
    exit 3
  end

  repos = require_list(repos, "profile [#{profile}] repos")
  puts repos
when 'base-repo-dir'
  puts config.fetch('base_repo_dir')
when 'workspace-root'
  puts config.fetch('workspace_root')
else
  abort "unknown command: #{command}"
end
