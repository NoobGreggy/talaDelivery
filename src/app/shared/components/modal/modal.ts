import { TalaIconComponent } from '../tala-icon/tala-icon';
import { Component, input, output } from '@angular/core';

@Component({
  selector: 'app-modal',
  standalone: true,
  imports: [TalaIconComponent],
  templateUrl: './modal.html',
  styleUrl: './modal.css',
})
export class ModalComponent {
  title = input('');
  open = input(false);
  size = input<'default' | 'wide'>('default');
  placement = input<'side' | 'center'>('side');
  closed = output<void>();

  close(): void {
    this.closed.emit();
  }
}
