import {
  ChangeDetectionStrategy, Component, EventEmitter, Input, Output,
} from '@angular/core';

export interface ITileViewEntry {
  text:string;
  attribute:string;
  icon:string;
  description:string;
  image:string;
  disabled?:boolean;
}

@Component({
  selector: 'tile-view',
  styleUrls: ['./tile-view.component.sass'],
  templateUrl: './tile-view.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class TileViewComponent {
  @Input() public tiles:ITileViewEntry[];

  @Input() public disable = false;

  @Output() public create = new EventEmitter<string>();

  public created(attribute:string) {
    this.create.emit(attribute);
  }
}
