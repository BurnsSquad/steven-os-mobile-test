# Shared-screen navigation — v153

Shared family screens now have a clear current-section title, explanation and active navigation state. Tasks & Activities, Groceries and Calendar are separate destinations; parent Finance remains adult-only. Task/Activity tabs and planner refresh appear only inside the planner, so they cannot be mistaken for grocery controls.

On phone widths the shared navigation stays at the top while scrolling. Buttons have large touch targets and text wraps without horizontal overflow. The signed-in shared screens omit the large introductory hero and pilot notice to bring the actual destination into view; sign-out restores the introduction. These changes do not restyle the original private OS frame or change its records.

The original toolbar now offers Shared groceries, which opens the same household list in the shared screen. Returning to Original Steven OS retains the loaded private frame. Original/private data does not become shared through this navigation.

Validation: shared browser mock checks sticky navigation while scrolled, section heading/current-page state, planner-only tab visibility, cross-context groceries, child Finance restrictions, mobile fit and sign-out cleanup. Original-source regression checks the grocery shortcut and returning to the private frame, along with existing eleven-tab/five-calendar-view, routine, Finance, recovery and private snapshot checks. An initial test waited for the desktop sidebar at phone width; the assertion was corrected to the original mobile navigation. This was a test-selector issue, not a lost original tab.

Live evidence recorded separately: the user confirmed the grocery item appeared on another device, was picked up there and displayed the correct pickup name back in the original Groceries section on v152. This confirms that grocery flow; it is not blanket real-device acceptance of every feature or a claim of actual session-lifetime testing. The new v153 navigation has automated browser coverage, not a fresh physical-device sign-in claim.
