## ADDED Requirements

### Requirement: Quick Look for clipboard entries
The Clipboard History palette SHALL offer a "Quick Look" action, on ⌘Y and as a row in the ⌘K actions
menu, for image entries and file entries. It SHALL show the entry's content inside the palette, in
the same preview card File Search uses: images and documents rendered, PDFs scrollable, videos and
audio playable. Text entries SHALL NOT offer it.

#### Scenario: Image entry
- **WHEN** an image entry is selected and the user presses ⌘Y
- **THEN** the image opens in the Quick Look card over the clipboard list and the palette stays open

#### Scenario: PDF file entry
- **WHEN** a copied PDF file is selected and the user picks Quick Look in the ⌘K menu
- **THEN** the PDF opens in the card and can be scrolled

#### Scenario: Video file entry
- **WHEN** a copied video file is selected and the user presses ⌘Y
- **THEN** the video opens in the card and starts playing

#### Scenario: Text entry
- **WHEN** a text entry is selected
- **THEN** ⌘Y does nothing and the ⌘K menu has no Quick Look row

### Requirement: Quick Look follows the selection and closes cleanly
While the Quick Look card is open, moving the selection SHALL show the newly selected entry, and Esc
SHALL close the card and leave the palette open. Hiding the palette, leaving the clipboard screen or
selecting an entry that does not offer Quick Look SHALL close the card and stop any playback.

#### Scenario: Arrow to the next entry
- **WHEN** the card is open and the user presses ↓ onto another image or file entry
- **THEN** the card shows that entry

#### Scenario: Esc
- **WHEN** the card is open and the user presses Esc
- **THEN** the card closes and the clipboard list is shown again

#### Scenario: Palette hidden while playing
- **WHEN** a video is playing in the card and the palette is hidden
- **THEN** playback stops and the card is closed the next time the palette opens

### Requirement: Zoom in the Quick Look card
The Quick Look card SHALL let the user zoom images and PDFs with a mouse or a trackpad: scrolling
while holding ⌘ zooms in and out around the pointer, ⌘+ and ⌘− zoom in and out by steps, and a
double-click on an image toggles between fitting the card and its actual size. A zoomed image or PDF
SHALL scroll in every direction to reach any part of it, and a zoomed image SHALL also move by
clicking and dragging it, with a hand cursor. Each entry SHALL open fitted to the card, and zoom
SHALL NOT carry over when the selection changes. Videos and text are not zoomable.

#### Scenario: Command-scroll an image
- **WHEN** an image is open in the card and the user scrolls up while holding ⌘, with a mouse wheel
  or two fingers on a trackpad
- **THEN** the image grows around the pointer and can be scrolled to see its edges

#### Scenario: Drag a zoomed image
- **WHEN** an image is zoomed beyond the card and the user clicks and drags it
- **THEN** the image follows the pointer, and the cursor is a hand while over it

#### Scenario: Keyboard zoom
- **WHEN** an image or PDF is open in the card and the user presses ⌘+ twice and then ⌘−
- **THEN** the content zooms in two steps and back one step

#### Scenario: Double-click an image
- **WHEN** a fitted image is double-clicked
- **THEN** it shows at actual size, and a second double-click fits it to the card again

#### Scenario: Next entry starts fitted
- **WHEN** the user zooms an image and presses ↓ onto another image entry
- **THEN** the new image opens fitted to the card

### Requirement: Missing content is reported
When the file or stored image behind the selected entry no longer exists, Quick Look SHALL NOT open
and the system SHALL show a message saying the file or image is no longer available.

#### Scenario: Deleted file
- **WHEN** the selected file entry's file was deleted and the user presses ⌘Y
- **THEN** no card opens and a "That file has moved or been deleted." message is shown
