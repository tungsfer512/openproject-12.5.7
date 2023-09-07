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

import {
  ChangeDetectionStrategy, ChangeDetectorRef, Component, ElementRef, Inject, OnInit,
} from '@angular/core';
import { OpModalComponent } from 'core-app/shared/components/modal/modal.component';
import { OpModalLocalsToken, OpModalService } from 'core-app/shared/components/modal/modal.service';
import { OpModalLocalsMap } from 'core-app/shared/components/modal/modal.types';
import { I18nService } from 'core-app/core/i18n/i18n.service';
import { WorkPackageResource } from 'core-app/features/hal/resources/work-package-resource';
import idFromLink from 'core-app/features/hal/helpers/id-from-link';
import { ApiV3Service } from 'core-app/core/apiv3/api-v3.service';
import { StateService } from '@uirouter/core';

@Component({
  templateUrl: './wp-preview.modal.html',
  styleUrls: ['./wp-preview.modal.sass'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class WpPreviewModalComponent extends OpModalComponent implements OnInit {
  public workPackage:WorkPackageResource;

  public text = {
    created_by: this.i18n.t('js.label_created_by'),
  };

  constructor(readonly elementRef:ElementRef,
    @Inject(OpModalLocalsToken) readonly locals:OpModalLocalsMap,
    readonly cdRef:ChangeDetectorRef,
    readonly i18n:I18nService,
    readonly apiV3Service:ApiV3Service,
    readonly opModalService:OpModalService,
    readonly $state:StateService) {
    super(locals, cdRef, elementRef);
  }

  ngOnInit() {
    super.ngOnInit();
    const { workPackageLink } = this.locals;
    const workPackageId = idFromLink(workPackageLink);

    this
      .apiV3Service
      .work_packages
      .id(workPackageId)
      .requireAndStream()
      .subscribe((workPackage:WorkPackageResource) => {
        this.workPackage = workPackage;
        this.cdRef.detectChanges();

        const modal = jQuery(this.elementRef.nativeElement);
        this.reposition(modal, this.locals.event.target);
      });
  }

  public reposition(element:JQuery<HTMLElement>, target:JQuery<HTMLElement>) {
    element.position({
      my: 'right top',
      at: 'right bottom',
      of: target,
      collision: 'flipfit',
    });
  }

  public openStateLink(event:{ workPackageId:string; requestedState:string }) {
    const params = { workPackageId: event.workPackageId };

    this.$state.go(event.requestedState, params);
  }
}
