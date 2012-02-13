SimpleCov.start do
  add_filter "/spec/.*_spec\.rb"
  add_filter "/spec/.*/shared_examples.*"
  add_filter "/spec/.*/.*helper(s?).rb"
end

# vim: filetype=ruby
