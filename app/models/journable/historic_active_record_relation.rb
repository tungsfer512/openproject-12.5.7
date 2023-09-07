#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2022 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

# rubocop:disable Style/ClassCheck
#   Prefer `kind_of?` over `is_a?` because it reads well before vowel and consonant sounds.
#   E.g.: `relation.kind_of? ActiveRecord::Relation`

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/PerceivedComplexity

# In the context of the baseline-comparison feature, this class represents an active-record relation
# that queries historic data, i.e. performs its query e.g. on the `work_package_journals` table
# rather than the `work_packages` table.
#
# Usage:
#
#     timestamp = 1.year.ago
#     active_record_relation = WorkPackage.where(subject: "Foo")
#     historic_relation = Journable::HistoricActiveRecordRelation.new(active_record_relation, timestamp:)
#
# See also:
#
# - https://github.com/opf/openproject/pull/11243
# - https://community.openproject.org/projects/openproject/work_packages/26448
#
class Journable::HistoricActiveRecordRelation < ActiveRecord::Relation
  attr_accessor :timestamp

  include ActiveRecord::Delegation::ClassSpecificRelation

  def initialize(relation, timestamp:)
    raise ArgumentError, "Expected ActiveRecord::Relation" unless relation.kind_of? ActiveRecord::Relation

    super(relation.klass)
    relation.instance_variables.each do |key|
      instance_variable_set key, relation.instance_variable_get(key)
    end

    self.timestamp = timestamp
    readonly!
    instance_variable_set :@table, model.journal_class.arel_table
  end

  # We need to patch the `pluck` method of an active-record relation that
  # queries historic data (i.e. journal data). Otherwise, `pluck(:id)`
  # would return the `id` of the journal table rather than the `id` of the
  # journable table, which would be expected from the syntax:
  #
  #     WorkPackage.where(assigned_to_id: 123).at_timestamp(1.year.ago).pluck(:id)
  #
  def pluck(*column_names)
    column_names.map! do |column_name|
      case column_name
      when :id, 'id'
        'journals.journable_id'
      when :created_at, 'created_at'
        'journables.created_at'
      when :updated_at, 'updated_at'
        'journals.updated_at'
      else
        if model.column_names_missing_in_journal.include?(column_name.to_s)
          Rails.logger.warn "Cannot pluck column `#{column_name}` because this attribute is not journalized," \
                            "i.e. it is missing in the #{journal_class.table_name} table."
          "null as #{column_name}"
        else
          column_name
        end
      end
    end
    arel
    super
  end

  alias_method :original_build_arel, :build_arel

  # Patch the arel object, which is used to construct the sql query, in order
  # to modify the query to search for historic data.
  #
  def build_arel(aliases = nil)
    relation = self

    relation = switch_to_journals_database_table(relation)
    relation = substitute_database_table_in_where_clause(relation)
    relation = add_timestamp_condition(relation)
    relation = add_join_on_journables_table_with_created_at_column(relation)
    relation = add_join_projects_on_journables(relation)
    relation = select_columns_from_the_appropriate_tables(relation)

    # Based on the previous modifications, build the algebra object.
    arel = relation.call_original_build_arel(aliases)
    arel = modify_order_clauses(arel)
    modify_joins(arel)
  end

  def call_original_build_arel(aliases = nil)
    original_build_arel(aliases)
  end

  def eager_loading?
    false
  end

  private

  # Switch the database table, e.g. from `work_packages` to `work_package_journals`.
  #
  def switch_to_journals_database_table(relation)
    relation.instance_variable_set :@table, model.journal_class.arel_table
    relation
  end

  # Modify the where clauses such that e.g. the work-packages table is substituted
  # with the work-package-journals table.
  #
  # When the where clause contains the `id` column, use `journals.journable_id` instead.
  #
  def substitute_database_table_in_where_clause(relation)
    relation.where_clause.instance_variable_get(:@predicates).each do |predicate|
      substitute_database_table_in_predicate(predicate)
    end
    relation
  end

  # In sql, a *predicate* is an expression that evaluates to `true`, `false` or "unknown". [1]
  # In active-record relations, predicates are components of where clauses.
  #
  # We need to substitute the table name ("work_packages") with the journalized table name
  # ("work_package_journals") in order to retrieve historic data from the journalized table.
  #
  # However, there are columns where we need to retrieve the data from another table,
  # in particular:
  #
  # - `id`
  # - `created_at`
  # - `updated_at`
  #
  # When asking for `WorkPackage.at_timestamp(...).where(id: 123)`, we are expecting `id` to refer
  # to the id of the work pacakge, not of the journalized table entry.
  #
  # Also, the `created_at` and `updated_at` columns are not included in the journalized table.
  # We gather the `updated_at` from the `journals` mapping table, and the `created_at` from the
  # model's table (`work_packages`) itself.
  #
  # [1] https://learn.microsoft.com/en-us/sql/t-sql/queries/predicates
  #
  def substitute_database_table_in_predicate(predicate)
    case predicate
    when String
      gsub_table_names_in_sql_string!(predicate)
    when Arel::Nodes::HomogeneousIn,
         Arel::Nodes::In,
         Arel::Nodes::NotIn,
         Arel::Nodes::Equality,
         Arel::Nodes::NotEqual,
         Arel::Nodes::LessThan,
         Arel::Nodes::LessThanOrEqual,
         Arel::Nodes::GreaterThan,
         Arel::Nodes::GreaterThanOrEqual
      if predicate.left.relation == arel_table or predicate.left.relation == journal_class.arel_table
        case predicate.left.name
        when "id"
          predicate.left.name = "journable_id"
          predicate.left.relation = Journal.arel_table
        when "updated_at"
          predicate.left.relation = Journal.arel_table
        when "created_at"
          predicate.left = Arel::Nodes::SqlLiteral.new("\"journables\".\"created_at\"")
        else
          predicate.left.relation = journal_class.arel_table
        end
      end
    when Arel::Nodes::Grouping
      substitute_database_table_in_predicate(predicate.expr.left)
      substitute_database_table_in_predicate(predicate.expr.right)
    else
      raise NotImplementedError, "FIXME A predicate of type #{predicate.class.name} is not handled, yet."
    end
  end

  # Add a timestamp condition: Select the work package journals that are the
  # current ones at the given timestamp.
  #
  def add_timestamp_condition(relation)
    relation.joins_values = [journals_join_statement] + relation.joins_values
    relation.merge(Journal.where(journable_type: model.name).at_timestamp(timestamp))
  end

  def journals_join_statement
    "INNER JOIN \"journals\" ON \"journals\".\"data_type\" = '#{model.journal_class.name}' " \
      "AND \"journals\".\"data_id\" = \"#{model.journal_class.table_name}\".\"id\""
  end

  # Join the journables table itself because we need to take the `created_at` attribute from that.
  # The `created_at` column is not present in the `work_package_journals` table.
  #
  def add_join_on_journables_table_with_created_at_column(relation)
    relation \
        .joins("INNER JOIN (SELECT id, created_at#{', project_id' if include_projects?(relation)} " \
               "FROM \"#{model.table_name}\") AS journables " \
               "ON \"journables\".\"id\" = \"journals\".\"journable_id\"")
  end

  # Join the projects table on journables if :project is in the includes.
  # It is needed when projects are filtered by id, and has to be done manually
  # as eager_loading is disabled.
  # Does not work yet for other includes.
  #
  def add_join_projects_on_journables(relation)
    if include_projects?(relation)
      relation
        .except(:includes, :eager_load, :preload)
        .joins('LEFT OUTER JOIN "projects" ' \
               'ON "projects"."id" = "journables"."project_id"')
    else
      relation
    end
  end

  def include_projects?(relation)
    include_values = relation.values.fetch(:includes, [])
    include_values.include?(:project)
  end

  # Gather the columns we need in our model from the different tables in the sql query:
  #
  # - the `work_packages` table (journables)
  # - the `work_package_journals` table (data)
  # - the `journals` table
  #
  # Also, add the `timestamp` as column so that we have it as attribute in our model.
  #
  def select_columns_from_the_appropriate_tables(relation)
    if relation.select_values.count == 0
      relation = relation.select(column_select_definitions.join(", "))
    elsif relation.select_values.count == 1 and
        relation.select_values.first.respond_to? :relation and
        relation.select_values.first.relation.name == model.journal_class.table_name and
        relation.select_values.first.name == "id"
      # For sub queries, we need to use the journals.journable_id as well.
      # See https://github.com/fiedl/openproject/issues/3.
      relation.instance_variable_get(:@values)[:select] = []
      relation = relation.select("journals.journable_id as id")
    end
    relation
  end

  def column_select_definitions
    [
      "#{model.journal_class.table_name}.*",
      "journals.journable_id as id",
      "journables.created_at as created_at",
      "journals.updated_at as updated_at",
      "'#{timestamp}' as timestamp"
    ] + \
    model.column_names_missing_in_journal.collect do |missing_column_name|
      "null as #{missing_column_name}"
    end
  end

  # Modify order clauses to use the work-pacakge-journals table.
  #
  def modify_order_clauses(arel)
    arel.instance_variable_get(:@ast).instance_variable_get(:@orders).each do |order_clause|
      if order_clause.kind_of? Arel::Nodes::SqlLiteral
        gsub_table_names_in_sql_string!(order_clause)
      elsif order_clause.expr.relation == model.arel_table
        if order_clause.expr.name == "id"
          order_clause.expr.name = "journable_id"
          order_clause.expr.relation = Journal.arel_table
        else
          order_clause.expr.relation = model.journal_class.arel_table
        end
      end
    end
    arel
  end

  # Modify the joins to point to the journable_id.
  #
  def modify_joins(arel)
    arel.instance_variable_get(:@ast).instance_variable_get(:@cores).each do |core|
      core.instance_variable_get(:@source).right.each do |node|
        if node.kind_of? Arel::Nodes::StringJoin
          gsub_table_names_in_sql_string!(node.left)
        elsif node.kind_of?(Arel::Nodes::Join) and node.right.kind_of?(Arel::Nodes::On)
          [node.right.expr.left, node.right.expr.right].each do |attribute|
            if attribute.respond_to? :relation and
                (attribute.relation == journal_class.arel_table) and
                (attribute.name == "id")
              attribute.relation = Journal.arel_table
              attribute.name = "journable_id"
            end
          end
        end
      end
    end
    arel
  end

  # Replace table names in sql strings, e.g.
  #
  #     "work_package.id" => "journals.journable_id"
  #     "work_package.subject" => "work_package_journals.subject"
  #
  def gsub_table_names_in_sql_string!(sql_string)
    sql_string.gsub! /(?<!_)#{model.table_name}\.updated_at/, "journals.updated_at"
    sql_string.gsub! "\"#{model.table_name}\".\"updated_at\"", "\"journals\".\"updated_at\""
    sql_string.gsub! /(?<!_)#{model.table_name}\.created_at/, "journables.created_at"
    sql_string.gsub! "\"#{model.table_name}\".\"created_at\"", "\"journables\".\"created_at\""
    sql_string.gsub! /(?<!_)#{model.table_name}\.id/, "journals.journable_id"
    sql_string.gsub! "\"#{model.table_name}\".\"id\"", "\"journals\".\"journable_id\""
    sql_string.gsub! /(?<!_)#{model.table_name}\./, "#{model.journal_class.table_name}."
    sql_string.gsub! "\"#{model.table_name}\".", "\"#{model.journal_class.table_name}\"."
  end

  class NotImplementedError < StandardError; end
end

# rubocop:enable Style/ClassCheck
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/PerceivedComplexity
