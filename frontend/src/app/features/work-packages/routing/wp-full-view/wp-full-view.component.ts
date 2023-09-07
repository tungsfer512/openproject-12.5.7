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

import { WorkPackageResource } from 'core-app/features/hal/resources/work-package-resource';
import { StateService } from '@uirouter/core';
import { Component, Injector, OnInit } from '@angular/core';
import { of } from 'rxjs';
import {
  WorkPackageViewSelectionService,
} from 'core-app/features/work-packages/routing/wp-view-base/view-services/wp-view-selection.service';
import {
  WorkPackageSingleViewBase,
} from 'core-app/features/work-packages/routing/wp-view-base/work-package-single-view.base';
import { HalResourceNotificationService } from 'core-app/features/hal/services/hal-resource-notification.service';
import {
  WorkPackageNotificationService,
} from 'core-app/features/work-packages/services/notifications/work-package-notification.service';
import { WpSingleViewService } from 'core-app/features/work-packages/routing/wp-view-base/state/wp-single-view.service';
import { CommentService } from 'core-app/features/work-packages/components/wp-activity/comment-service';

@Component({
  templateUrl: './wp-full-view.html',
  selector: 'wp-full-view-entry',
  // Required class to support inner scrolling on page
  host: { class: 'work-packages-page--ui-view' },
  providers: [
    WpSingleViewService,
    CommentService,
    { provide: HalResourceNotificationService, useExisting: WorkPackageNotificationService },
  ],
})
export class WorkPackagesFullViewComponent extends WorkPackageSingleViewBase implements OnInit {
  // Watcher properties
  public isWatched:boolean;

  public displayWatchButton:boolean;

  public watchers:any;

  public text = {
    fullView: {
      buttonMore: this.i18n.t('js.button_more'),
    },
  };

  stateName$ = of('work-packages.new');

  constructor(
    public injector:Injector,
    public wpTableSelection:WorkPackageViewSelectionService,
    readonly $state:StateService,
    // private readonly i18n:I18nService,
  ) {
    super(injector, $state.params.workPackageId);
  }

  ngOnInit():void {
    this.observeWorkPackage();
  }

  protected init() {
    super.init();

    // Set Focused WP
    this.wpTableFocus.updateFocus(this.workPackage.id!);

    this.setWorkPackageScopeProperties(this.workPackage);
  }

  private setWorkPackageScopeProperties(wp:WorkPackageResource) {
    this.isWatched = wp.hasOwnProperty('unwatch');
    this.displayWatchButton = wp.hasOwnProperty('unwatch') || wp.hasOwnProperty('watch');

    // watchers
    if (wp.watchers) {
      this.watchers = (wp.watchers as any).elements;
    }
  }
}
