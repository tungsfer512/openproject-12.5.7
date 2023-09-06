#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2023 the OpenProject GmbH
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

module JournalChanges
  def get_changes
    return @changes if @changes
    return {} if data.nil?

    @changes = if predecessor.nil?
                 initial_journal_data_changes
               else
                 subsequent_journal_data_changes
               end

    @changes.merge!(get_association_changes(predecessor, 'attachable', 'attachments', :attachment_id, :filename))
    @changes.merge!(get_association_changes(predecessor, 'customizable', 'custom_fields', :custom_field_id, :value))
  end

  private

  def initial_journal_data_changes
    data
     .journaled_attributes
     .compact
     .inject({}) do |result, (attribute, new_value)|
      result[attribute] = [nil, new_value]
      result
    end
  end

  def subsequent_journal_data_changes
    ::Acts::Journalized::JournableDiffer.changes(predecessor.data, data)
  end

  def get_association_changes(predecessor, journal_association, association, key, value)
    journal_assoc_name = "#{journal_association}_journals"

    if predecessor.nil?
      send(journal_assoc_name).each_with_object({}) do |associated_journal, h|
        changed_attribute = "#{association}_#{associated_journal.send(key)}"
        new_value = associated_journal.send(value)
        h[changed_attribute] = [nil, new_value]
      end
    else
      new_journals = send(journal_assoc_name).map(&:attributes)
      old_journals = predecessor.send(journal_assoc_name).map(&:attributes)

      changes_on_association(new_journals, old_journals, association, key, value)
    end
  end

  def changes_on_association(current, predecessor, association, key, value)
    merged_journals = merge_reference_journals_by_id(current, predecessor, key.to_s, value.to_s)

    changes = added_references(merged_journals)
                .merge(removed_references(merged_journals))
                .merge(changed_references(merged_journals))

    to_changes_format(changes, association.to_s)
  end

  def added_references(merged_references)
    merged_references
      .select { |_, (old_value, new_value)| old_value.nil? && new_value.present? }
  end

  def removed_references(merged_references)
    merged_references
      .select { |_, (old_value, new_value)| old_value.present? && new_value.nil? }
  end

  def changed_references(merged_references)
    merged_references
      .select { |_, (old_value, new_value)| old_value.present? && new_value.present? && old_value.strip != new_value.strip }
  end

  def to_changes_format(references, key)
    references.each_with_object({}) do |(id, (old_value, new_value)), result|
      result["#{key}_#{id}"] = [old_value, new_value]
    end
  end

  def merge_reference_journals_by_id(new_journals, old_journals, id_key, value)
    all_associated_journal_ids = new_journals.map { |j| j[id_key] } | old_journals.map { |j| j[id_key] }

    all_associated_journal_ids.index_with do |id|
      [select_and_combine_journals(old_journals, id, id_key, value),
       select_and_combine_journals(new_journals, id, id_key, value)]
    end
  end

  def select_and_combine_journals(journals, id, key, value)
    selected_journals = journals.select { |j| j[key] == id }.map { |j| j[value] }

    if selected_journals.empty?
      nil
    else
      selected_journals.sort.join(',')
    end
  end
end
