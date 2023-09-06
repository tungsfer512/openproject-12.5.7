import {
  AfterViewInit,
  Component,
  Injector,
  OnInit,
} from '@angular/core';
import { Observable } from 'rxjs';
import { I18nService } from 'core-app/core/i18n/i18n.service';
import { BoardService } from 'core-app/features/boards/board/board.service';
import { Board } from 'core-app/features/boards/board/board';
import { ToastService } from 'core-app/shared/components/toaster/toast.service';
import { OpModalService } from 'core-app/shared/components/modal/modal.service';
import { NewBoardModalComponent } from 'core-app/features/boards/new-board-modal/new-board-modal.component';
import { LoadingIndicatorService } from 'core-app/core/loading-indicator/loading-indicator.service';
import { AuthorisationService } from 'core-app/core/model-auth/model-auth.service';
import { UntilDestroyedMixin } from 'core-app/shared/helpers/angular/until-destroyed.mixin';
import { componentDestroyed } from '@w11k/ngx-componentdestroyed';
import { ApiV3Service } from 'core-app/core/apiv3/api-v3.service';
import { map } from 'rxjs/operators';

@Component({
  templateUrl: './boards-index-page.component.html',
  styleUrls: ['./boards-index-page.component.sass'],
})
export class BoardsIndexPageComponent extends UntilDestroyedMixin implements OnInit, AfterViewInit {
  public text = {
    name: this.I18n.t('js.modals.label_name'),
    create: this.I18n.t('js.button_create'),
    create_new_board: this.I18n.t('js.boards.create_new'),
    board: this.I18n.t('js.label_board'),
    boards: this.I18n.t('js.label_board_plural'),
    type: this.I18n.t('js.boards.label_board_type'),
    type_free: this.I18n.t('js.boards.board_type.free'),
    action_by_attribute: (attr:string) => this.I18n.t('js.boards.board_type.action_by_attribute',
      { attribute: this.I18n.t(`js.boards.board_type.action_type.${attr}`) }),
    createdAt: this.I18n.t('js.label_created_on'),
    delete: this.I18n.t('js.button_delete'),
    areYouSure: this.I18n.t('js.text_are_you_sure'),
    deleteSuccessful: this.I18n.t('js.notice_successful_delete'),
    noResults: this.I18n.t('js.notice_no_results_to_display'),
  };

  public canAdd = false;

  public boards$:Observable<Board[]> = this
    .apiV3Service
    .boards
    .observeAll()
    .pipe(
      map((boards:Board[]) => boards.sort((a, b) => a.name.localeCompare(b.name))),
    );

  constructor(
    private readonly boardService:BoardService,
    private readonly apiV3Service:ApiV3Service,
    private readonly I18n:I18nService,
    private readonly toastService:ToastService,
    private readonly opModalService:OpModalService,
    private readonly loadingIndicatorService:LoadingIndicatorService,
    private readonly authorisationService:AuthorisationService,
    private readonly injector:Injector,
  ) {
    super();
  }

  ngOnInit():void {
    this.authorisationService
      .observeUntil(componentDestroyed(this))
      .subscribe(() => {
        this.canAdd = this.authorisationService.can('boards', 'create');
      });
  }

  ngAfterViewInit():void {
    const loadingIndicator = this.loadingIndicatorService.indicator('boards-module');
    loadingIndicator.promise = this.boardService.loadAllBoards();
  }

  newBoard():void {
    this.opModalService.show(NewBoardModalComponent, this.injector);
  }

  destroyBoard(board:Board):void {
    if (!window.confirm(this.text.areYouSure)) {
      return;
    }

    this.boardService
      .delete(board)
      .then(() => {
        this.toastService.addSuccess(this.text.deleteSuccessful);
      })
      .catch((error) => this.toastService.addError(`Deletion failed: ${error}`));
  }
}
