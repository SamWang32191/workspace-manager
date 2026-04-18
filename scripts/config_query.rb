#!/usr/bin/env ruby
require 'yaml'

def invalid_config(message)
  abort "Invalid config: #{message}"
end

def load_config(path)
  YAML.load_file(path) || {}
rescue Psych::Exception => e
  invalid_config(e.message)
rescue SystemCallError => e
  invalid_config(e.message)
end

def fetch_required(config, key, message)
  value = config[key]
  return value unless value.nil?

  invalid_config(message)
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

def require_profile_keys(profiles)
  return profiles if profiles.keys.all? { |key| key.is_a?(String) }

  invalid_config('profile keys must be strings')
end

def require_repo_names(repos, profile)
  return repos if repos.all? { |repo| repo.is_a?(String) && !repo.empty? }

  invalid_config("profile [#{profile}] repos must contain non-empty strings")
end

def require_profiles(profiles)
  profiles = require_profile_keys(profiles)

  profiles.each do |profile, repos|
    repos = require_list(repos, "profile [#{profile}] repos")
    require_repo_names(repos, profile)
  end

  profiles
end

config_path = ARGV.shift or abort 'missing config path'
command = ARGV.shift or abort 'missing command'

config = load_config(config_path)
config = require_mapping(config, 'root config')

case command
when 'list-profiles'
  profiles = require_mapping(fetch_required(config, 'profiles', 'profiles must be a mapping'), 'profiles')
  profiles = require_profiles(profiles)
  puts profiles.keys.sort
when 'profile-repos'
  profile = ARGV.shift or abort 'missing profile'
  profiles = require_mapping(fetch_required(config, 'profiles', 'profiles must be a mapping'), 'profiles')
  profiles = require_profile_keys(profiles)
  unless profiles.key?(profile)
    warn "unknown profile: #{profile}"
    exit 3
  end

  repos = profiles[profile]
  repos = require_list(repos, "profile [#{profile}] repos")
  repos = require_repo_names(repos, profile)
  puts repos
when 'base-repo-dir'
  puts require_string(fetch_required(config, 'base_repo_dir', 'base_repo_dir must be a string'), 'base_repo_dir')
when 'workspace-root'
  puts require_string(fetch_required(config, 'workspace_root', 'workspace_root must be a string'), 'workspace_root')
else
  abort "unknown command: #{command}"
end
