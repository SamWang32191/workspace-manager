#!/usr/bin/env ruby
require 'yaml'

config_path = ARGV.shift or abort 'missing config path'
command = ARGV.shift or abort 'missing command'

config = YAML.load_file(config_path) || {}

case command
when 'list-profiles'
  profiles = config.fetch('profiles')
  puts profiles.keys.sort
when 'profile-repos'
  profile = ARGV.shift or abort 'missing profile'
  profiles = config.fetch('profiles')
  repos = profiles[profile]
  if repos.nil?
    warn "unknown profile: #{profile}"
    exit 3
  end

  puts repos
when 'base-repo-dir'
  puts config.fetch('base_repo_dir')
when 'workspace-root'
  puts config.fetch('workspace_root')
else
  abort "unknown command: #{command}"
end
