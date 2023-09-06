Gem::Specification.new do |s|
  s.name        = "openproject-xls_export"
  s.version     = '1.0.0'
  s.authors     = "OpenProject GmbH"
  s.email       = "info@openproject.com"
  s.summary     = 'OpenProject XLS Export'
  s.description = 'Export issue lists as Excel spreadsheets (.xls). Support for exporting
    cost entries and cost reports is not yet migrated to Rails 3 and disabled.'
  s.license     = "GPLv3"

  s.files = Dir["{app,config,db,lib}/**/*"] + %w(CHANGELOG.md README.md)

  s.add_dependency "spreadsheet", "~>1.3.0"
  s.metadata['rubygems_mfa_required'] = 'true'
end
