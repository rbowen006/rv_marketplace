import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ConfirmDialog } from './ConfirmDialog';

function renderDialog(props: Partial<Parameters<typeof ConfirmDialog>[0]> = {}) {
  const onConfirm = vi.fn();
  const onCancel = vi.fn();
  render(
    <ConfirmDialog
      title="Start over?"
      message="This permanently deletes this conversation."
      confirmLabel="Start over"
      onConfirm={onConfirm}
      onCancel={onCancel}
      {...props}
    />,
  );
  return { onConfirm, onCancel };
}

it('never submits a surrounding form', async () => {
  const onSubmit = vi.fn((e: React.FormEvent) => e.preventDefault());
  const onConfirm = vi.fn();
  render(
    <form onSubmit={onSubmit}>
      <ConfirmDialog
        title="Replace it?"
        message="This overwrites what's there."
        confirmLabel="Replace"
        onConfirm={onConfirm}
        onCancel={vi.fn()}
      />
    </form>,
  );

  await userEvent.click(screen.getByRole('button', { name: 'Replace' }));

  expect(onConfirm).toHaveBeenCalledOnce();
  expect(onSubmit).not.toHaveBeenCalled();
});

it('focuses cancel on open, so a stray Enter never confirms', () => {
  renderDialog();

  expect(screen.getByRole('button', { name: 'Cancel' })).toHaveFocus();
});

// Call sites pass inline arrows for onCancel, and pages behind the dialog poll on a
// timer — so the dialog re-renders with a fresh callback identity while it's open.
it('keeps focus where the user put it when the parent re-renders', async () => {
  const { rerender } = render(
    <ConfirmDialog title="Start over?" message="Deletes it." confirmLabel="Start over" onConfirm={vi.fn()} onCancel={vi.fn()} />,
  );

  const confirmButton = screen.getByRole('button', { name: 'Start over' });
  await userEvent.tab();
  confirmButton.focus();

  rerender(
    <ConfirmDialog title="Start over?" message="Deletes it." confirmLabel="Start over" onConfirm={vi.fn()} onCancel={vi.fn()} />,
  );

  expect(confirmButton).toHaveFocus();
});

it('cancels when the cancel button is clicked', async () => {
  const { onConfirm, onCancel } = renderDialog();

  await userEvent.click(screen.getByRole('button', { name: 'Cancel' }));

  expect(onCancel).toHaveBeenCalledOnce();
  expect(onConfirm).not.toHaveBeenCalled();
});

it('cancels when the backdrop is clicked', async () => {
  const { onConfirm, onCancel } = renderDialog();

  await userEvent.click(screen.getByTestId('confirm-backdrop'));

  expect(onCancel).toHaveBeenCalledOnce();
  expect(onConfirm).not.toHaveBeenCalled();
});

it('cancels when Escape is pressed', async () => {
  const { onConfirm, onCancel } = renderDialog();

  await userEvent.keyboard('{Escape}');

  expect(onCancel).toHaveBeenCalledOnce();
  expect(onConfirm).not.toHaveBeenCalled();
});

it('confirms the action when the confirm button is clicked', async () => {
  const { onConfirm, onCancel } = renderDialog();

  expect(screen.getByText('Start over?')).toBeInTheDocument();
  expect(screen.getByText('This permanently deletes this conversation.')).toBeInTheDocument();

  await userEvent.click(screen.getByRole('button', { name: 'Start over' }));

  expect(onConfirm).toHaveBeenCalledOnce();
  expect(onCancel).not.toHaveBeenCalled();
});
