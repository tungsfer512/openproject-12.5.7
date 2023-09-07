import { ComponentFixture, TestBed } from '@angular/core/testing';
import { DebugElement } from '@angular/core';
import { By } from '@angular/platform-browser';
import { imagePath } from 'core-app/shared/helpers/images/path-helper';
import { TileViewComponent } from './tile-view.component';

describe('shows tiles', () => {
  let app:TileViewComponent;
  let fixture:ComponentFixture<TileViewComponent>;
  let element:DebugElement;

  const tilesStub = [{
    attribute: 'basic',
    text: 'Basic board',
    icon: 'icon-boards',
    image: imagePath('board_creation_modal/lists.svg'),
    description: `Create a board in which you can freely
  create lists and order your work packages within.
  Moving work packages between lists do not change the work package itself.`,
  }];

  beforeEach(() => {
    TestBed.configureTestingModule({
      declarations: [
        TileViewComponent],
      providers: [],
    }).compileComponents();

    fixture = TestBed.createComponent(TileViewComponent);
    app = fixture.debugElement.componentInstance;
    app.tiles = tilesStub;
    element = fixture.debugElement;
  });

  it('should render the component successfully', () => {
    fixture.detectChanges();
    const tile = document.querySelector('.op-tile-block--title');
    expect(document.contains(tile)).toBeTruthy();
  });

  it('should show each tile', () => {
    fixture.detectChanges();
    const tile:HTMLElement = element.query(By.css('.op-tile-block--title')).nativeElement;
    expect(tile.textContent).toContain('Basic');
  });

  it('should show the image', () => {
    fixture.detectChanges();
    const tile = document.querySelector('.op-tile-block--image');
    expect(document.contains(tile)).toBeTruthy();
  });
});
