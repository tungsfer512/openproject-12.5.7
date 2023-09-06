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
  ChangeDetectorRef,
  Component,
  ElementRef,
  Inject,
  OnInit,
  ViewChild,
} from '@angular/core';
import { OpModalComponent } from 'core-app/shared/components/modal/modal.component';
import { OpModalLocalsToken } from 'core-app/shared/components/modal/modal.service';
import { OpModalLocalsMap } from 'core-app/shared/components/modal/modal.types';
import { I18nService } from 'core-app/core/i18n/i18n.service';
import { BoardType } from 'core-app/features/boards/board/board';
import { StateService } from '@uirouter/core';
import { BoardService } from 'core-app/features/boards/board/board.service';
import { BoardActionsRegistryService } from 'core-app/features/boards/board/board-actions/board-actions-registry.service';
import { LoadingIndicatorService } from 'core-app/core/loading-indicator/loading-indicator.service';
import { HalResourceNotificationService } from 'core-app/features/hal/services/hal-resource-notification.service';
import { imagePath } from 'core-app/shared/helpers/images/path-helper';
import { ITileViewEntry } from '../tile-view/tile-view.component';
import { BannersService } from 'core-app/core/enterprise/banners.service';
import { ToastService } from 'core-app/shared/components/toaster/toast.service';
import { enterpriseDocsUrl } from 'core-app/core/setup/globals/constants.const';

@Component({
  templateUrl: './new-board-modal.html',
})
export class NewBoardModalComponent extends OpModalComponent implements OnInit {
  @ViewChild('actionAttributeSelect', { static: true }) actionAttributeSelect:ElementRef;

  public showClose = true;

  public confirmed = false;

  public available = this.boardActions.available();

  public inFlight = false;

  public eeShowBanners = false;

  public text = {
    close_popup: this.I18n.t('js.close_popup_title'),

    free_board: this.I18n.t('js.boards.board_type.free'),
    free_board_text: this.I18n.t('js.boards.board_type.free_text'),
    free_board_title: this.I18n.t('js.boards.board_type.board_type_title.basic'),
    board_type: this.I18n.t('js.boards.board_type.text'),

    action_board: this.I18n.t('js.boards.board_type.action'),
    action_board_text: this.I18n.t('js.boards.board_type.action_text'),
    select_attribute: this.I18n.t('js.boards.board_type.select_attribute'),
    select_board_type: this.I18n.t('js.boards.board_type.select_board_type'),
    placeholder: this.I18n.t('js.placeholders.selection'),

    teaser_text: this.I18n.t('js.boards.upsale.teaser_text'),
    upgrade_to_ee_text: this.I18n.t('js.boards.upsale.upgrade'),
    more_info_ee_link: enterpriseDocsUrl.boards,
    cancel_button: this.I18n.t('js.button_cancel'),
  };

  constructor(
    @Inject(OpModalLocalsToken) public locals:OpModalLocalsMap,
    readonly elementRef:ElementRef,
    readonly cdRef:ChangeDetectorRef,
    readonly state:StateService,
    readonly boardService:BoardService,
    readonly boardActions:BoardActionsRegistryService,
    readonly halNotification:HalResourceNotificationService,
    readonly loadingIndicatorService:LoadingIndicatorService,
    readonly I18n:I18nService,
    readonly boardActionRegistry:BoardActionsRegistryService,
    readonly bannersService:BannersService,
    readonly toastService:ToastService,
  ) {
    super(locals, cdRef, elementRef);
    this.initiateTiles();
  }

  ngOnInit():void {
    super.ngOnInit();
    this.eeShowBanners = this.bannersService.eeShowBanners;
  }

  public createBoard(attribute:string):void {
    if (attribute === 'basic') {
      this.createFree();
    } else {
      this.createAction(attribute);
    }
  }

  private initiateTiles() {
    this.available.unshift({
      attribute: 'basic',
      text: this.text.free_board_title,
      icon: 'icon-boards',
      description: this.text.free_board_text,
      image: imagePath('board_creation_modal/lists.svg'),
    });
    this.addIcon(this.available);
    this.addDescription(this.available);
    this.addText(this.available);
    this.addImage(this.available);
  }

  private createFree() {
    this.create({ type: 'free' });
  }

  private createAction(attribute:string):void {
    if (this.eeShowBanners) {
      this.toastService.addError(this.I18n.t('js.upsale.ee_only'));
      return;
    }

    this.create({ type: 'action', attribute });
  }

  private create(params:{ type:BoardType, attribute?:string }) {
    this.inFlight = true;

    this.loadingIndicatorService.modal.promise = this.boardService
      .create(params)
      .then((board) => {
        this.inFlight = false;
        this.closeMe();
        this.state.go('boards.partitioned.show', { board_id: board.id, isNew: true });
      })
      .catch((error:unknown) => {
        this.inFlight = false;
        this.halNotification.handleRawError(error);
      });
  }

  private addDescription(tiles:ITileViewEntry[]) {
    tiles.forEach((element) => {
      if (element.attribute !== 'basic') {
        const service = this.boardActionRegistry.get(element.attribute);
        element.description = service.description;
      }
    });
  }

  private addIcon(tiles:ITileViewEntry[]) {
    tiles.forEach((element) => {
      if (element.attribute !== 'basic') {
        const service = this.boardActionRegistry.get(element.attribute);
        element.icon = service.icon;
      }
    });
  }

  private addText(tiles:ITileViewEntry[]) {
    tiles.forEach((element) => {
      if (element.attribute !== 'basic') {
        const service = this.boardActionRegistry.get(element.attribute);
        element.text = service.text;
      }
    });
  }

  private addImage(tiles:ITileViewEntry[]) {
    tiles.forEach((element) => {
      if (element.attribute !== 'basic') {
        const service = this.boardActionRegistry.get(element.attribute);
        element.image = service.image;
      }
    });
  }
}
