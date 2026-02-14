# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

require "dotsync"

# Load all tasks
Dir.glob(File.join(Gem.loaded_specs["dotsync"].full_gem_path, "lib", "dotsync", "tasks", "**/*.rake")).each { |f| load f }

RSpec::Core::RakeTask.new(:spec) do |t|
  # ENV['TEST_ENV'] = 'true'
end

task default: :spec

# Strip markdown formatting for plain-text contexts (git tag messages)
def strip_markdown(text)
  text
    .gsub(/\*\*(.+?)\*\*/, '\1')  # **bold** → bold
    .gsub(/`([^`]+)`/, '\1')      # `code`  → code
    .gsub(/\[([^\]]+)\]\([^)]+\)/, '\1') # [text](url) → text
end

# Load local version.rb, overriding any gem-installed constant
def local_version
  verbose = $VERBOSE
  $VERBOSE = nil
  load File.expand_path("lib/dotsync/version.rb", __dir__)
  $VERBOSE = verbose
  Dotsync::VERSION
end

namespace :release do
  desc "Generate CHANGELOG entry for a new version"
  # Usage: rake release:changelog[0.2.1]
  task :changelog, [:version] do |_t, args|
    version = args[:version]
    unless version
      version = local_version
    end
    version = version.sub(/^v/, "")
    today = Date.today.strftime("%Y-%m-%d")

    latest_tag = `git describe --tags --abbrev=0 2>/dev/null`.strip
    commits = if latest_tag.empty?
      `git log --oneline --no-decorate`.strip.split("\n")
    else
      `git log #{latest_tag}..HEAD --oneline --no-decorate`.strip.split("\n")
    end

    if commits.empty?
      abort "No commits since #{latest_tag}. Nothing to release."
    end

    categories = { "Added" => [], "Changed" => [], "Fixed" => [], "Removed" => [], "Security" => [], "Dependencies" => [] }

    commits.each do |commit|
      message = commit.sub(/^[a-f0-9]+\s+/, "")
      case message.downcase
      when /^add|^feat|^implement|^create|^new|^support/i then categories["Added"] << message
      when /^fix|^bugfix|^hotfix|^resolve|^correct/i then categories["Fixed"] << message
      when /^remove|^delete|^drop/i then categories["Removed"] << message
      when /^security|^vuln|^cve/i then categories["Security"] << message
      when /^bump|^upgrade|^update.*dependency|^dep/i then categories["Dependencies"] << message
      else categories["Changed"] << message
      end
    end

    changelog_entry = "## [#{version}] - #{today}\n"
    categories.each do |category, items|
      next if items.empty?
      changelog_entry += "\n### #{category}\n\n"
      items.each { |item| changelog_entry += "- #{item}\n" }
    end

    changelog_path = "CHANGELOG.md"
    abort "CHANGELOG.md not found." unless File.exist?(changelog_path)

    changelog = File.read(changelog_path)
    abort "Version #{version} already exists in CHANGELOG.md" if changelog.include?("[#{version}]")

    match = changelog.match(/^## \[/m)
    new_changelog = match ? changelog.sub(/^## \[/m, "#{changelog_entry}\n## [") : changelog.rstrip + "\n\n#{changelog_entry}"

    repo_url = `git remote get-url origin`.strip.sub(/\.git$/, "").sub(/^git@github\.com:/, "https://github.com/")
    previous_version = latest_tag.empty? ? "v0.0.0" : latest_tag
    link_entry = "[#{version}]: #{repo_url}/compare/#{previous_version}...v#{version}"

    new_changelog = if new_changelog.match?(/^\[[\d.]+\]:.*compare/m)
      new_changelog.sub(/^(\[[\d.]+\]:.*compare)/m, "#{link_entry}\n\\1")
    else
      new_changelog.rstrip + "\n\n#{link_entry}\n"
    end

    File.write(changelog_path, new_changelog)
    puts "Updated CHANGELOG.md with version #{version}"
    puts "\n#{changelog_entry}"
  end

  desc "Create annotated git tag from CHANGELOG"
  # Usage: rake release:tag[0.2.1] or just rake release:tag (uses Dotsync::VERSION)
  task :tag, [:version] do |_t, args|
    version = args[:version]
    unless version
      version = local_version
    end
    version = version.sub(/^v/, "")
    tag_name = "v#{version}"

    if `git tag --list`.split.include?(tag_name)
      puts "Tag #{tag_name} already exists."
      exit(1)
    end

    changelog_path = "CHANGELOG.md"
    abort "CHANGELOG.md not found." unless File.exist?(changelog_path)

    changelog = File.read(changelog_path)
    version_regex = /^## \[#{Regexp.escape(version)}\] - (\d{4}-\d{2}-\d{2})\n(.*?)(?=^## \[|\z)/m
    match = changelog.match(version_regex)

    unless match
      abort "Version #{version} not found in CHANGELOG.md\nRun 'rake release:changelog[#{version}]' first."
    end

    content = strip_markdown(match[2].strip)
    tag_message = "Release v#{version}\n\n#{content}"

    puts "Tagging commit as #{tag_name}..."
    puts "\n--- Tag message ---\n#{tag_message}\n---\n\n"
    sh "git", "tag", "-a", tag_name, "-m", tag_message
    puts "Tag created. Push with: git push origin #{tag_name}"
  end

  desc "Full release: update changelog, commit, tag, and push"
  # Usage: rake release:publish[0.2.1] or rake release:publish (uses Dotsync::VERSION)
  task :publish, [:version] do |_t, args|
    version = args[:version]
    unless version
      version = local_version
    end
    version = version.sub(/^v/, "")

    status = `git status --porcelain`.strip
    uncommitted = status.split("\n").reject { |line| line.end_with?("CHANGELOG.md") }
    abort "Uncommitted changes:\n#{uncommitted.join("\n")}" unless uncommitted.empty?

    Rake::Task["release:changelog"].invoke(version)
    puts "\nReview CHANGELOG.md, then press Enter to continue..."
    $stdin.gets

    sh "git", "add", "CHANGELOG.md"
    sh "git", "commit", "-m", "Update CHANGELOG for v#{version}\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)\n\nCo-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"

    Rake::Task["release:tag"].reenable
    Rake::Task["release:tag"].invoke(version)

    branch = `git rev-parse --abbrev-ref HEAD`.strip
    sh "git", "push", "origin", branch
    sh "git", "push", "origin", "v#{version}"
    puts "\n✅ Released v#{version}"
  end
end


namespace :dotsync do
  desc "Pull Dotfiles"
  task :pull do
    Dotsync::Runner.new.run(:pull)
  end

  desc "Push Dotfiles"
  task :push do
    Dotsync::Runner.new.run(:push)
  end

  desc "Watch Dotfiles"
  task :watch do
    Dotsync::Runner.new.run(:watch)
  end
end

namespace :palette do
  desc "Show palette background"
  task :bg do
    (0..255).each do |color|
      print "\e[48;5;#{color}m #{color.to_s.rjust(3)} \e[0m"
      puts if (color + 1) % 16 == 0
    end
  end

  desc "Show palette foreground"
  task :fg do
    (0..255).each do |color|
      print "\e[38;5;#{color}m\e[1m #{color.to_s.rjust(3)} \e[0m"
      puts if (color + 1) % 16 == 0
    end
  end
end
