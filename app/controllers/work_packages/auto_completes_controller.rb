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

require 'rack/utils'

class WorkPackages::AutoCompletesController < ApplicationController
  def index
    @work_packages = work_package_with_id | work_packages_by_subject_or_id

    respond_to do |format|
      format.json { render request.format.to_sym => wp_hashes_with_string(@work_packages) }
    end
  end

  private

  def work_package_with_id
    query_term = params[:q].to_s

    if query_term =~ /\A\d+\z/
      work_package_scope
        .visible.where(id: query_term.to_i)
        .order("#{WorkPackage.table_name}.updated_at DESC") # :id does not work because...
    else
      []
    end
  end

  def work_packages_by_subject_or_id
    query_term_sql = subject_or_id_query(params[:q].to_s)

    work_package_scope
      .visible
      .where(query_term_sql)
      .order("#{WorkPackage.table_name}.updated_at DESC") # :id does not work because...
      .limit(10)
      .includes(:type)
  end

  def wp_hashes_with_string(work_packages)
    work_packages.map do |work_package|
      wp_hash = Hash.new
      work_package.attributes.each { |key, value| wp_hash[key] = value }
      wp_hash['to_s'] = work_package.to_s
      wp_hash
    end
  end

  def subject_or_id_query(query_term)
    if query_term =~ /\A\d+\z/
      ["#{WorkPackage.table_name}.subject LIKE :q OR
       CAST(#{WorkPackage.table_name}.id AS CHAR(13)) LIKE :q",
       { q: "%#{query_term}%" }]
    else
      ["LOWER(#{WorkPackage.table_name}.subject) LIKE :q",
       { q: "%#{query_term.downcase}%" }]
    end
  end

  def work_package_scope
    WorkPackage.all
  end
end
