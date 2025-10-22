## Check list for releasing a new version

- [ ] From the root of your gem project, build the gem using `gem build`. This will create a `.gem` file.
- [ ] Install the gem locally using `gem install ./your-gem-name-version.gem`. This will install the gem, including its executable.
- [ ] After installation, the executable should be available globally in your shell path.
- [ ] To ensure the proper Ruby version is used, confirm that your environment is set up with the correct Ruby version (e.g., using a Ruby version manager like rbenv or rvm).
- [ ] From any location, you can now run the executable by typing its name (e.g., `dotsync`) to verify it works as expected.

