import { Component, input, output } from '@angular/core';

@Component({
  selector: 'app-modal',
  standalone: true,
  templateUrl: './modal.html',
  styleUrl: './modal.css',
})
export class ModalComponent {
  title = input('');
  open = input(false);
  size = input<'default' | 'wide'>('default');
  closed = output<void>();

  close(): void {
    this.closed.emit();
  }
}
