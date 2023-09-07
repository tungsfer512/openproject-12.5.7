// -- copyright
// OpenProject is an open source project management software.
// Copyright (C) 2012-2023 the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See COPYRIGHT and LICENSE files for more details.
//++

(function ($) {
  $(() => {
    // set selected page for menu tree if provided.
    $('[data-selected-page]').closest('.tree-menu--container').each((_i:number, tree:HTMLElement) => {
      const selectedPage = $(tree).data('selected-page');

      if (selectedPage) {
        const selected = $(`[slug="${selectedPage}"]`, tree);
        selected.toggleClass('-selected', true);
        if (selected.length > 0) {
          selected[0].scrollIntoView();
        }
      }
    });

    function toggle(event:any) {
      // ignore the event if a key different from ENTER was pressed.
      if (event.type === 'keypress' && event.which !== 13) {
        return false;
      }

      const target = $(event.target);
      const targetList = target.closest('ul.-with-hierarchy > li');
      targetList.toggleClass('-hierarchy-collapsed -hierarchy-expanded');
      return false;
    }

    // set click handlers for expanding and collapsing tree nodes
    $('.pages-hierarchy.-with-hierarchy .tree-menu--hierarchy-span').on('click keypress', toggle);
  });
}(jQuery));
