# Ask findings: what the source supports changing

The newly reached full Ask audit has four contrast findings (three unidentified, one `Explore a picture by touch`) and one clipped-text finding on `Everything in view`. These are failures, not ignored or assigned to guessed elements.

## Picker

DashboardView's Ask Form uses a default-style Picker labelled `Look at`, with six plain Text options. At Large the selected value shares the row horizontally with the label. The inspected Large screenshot shows a readable value. The native clipped-text finding names that selected UILabel at larger sizes; no larger-size screenshot of this control was retained.

A controlled candidate is an inline standard Picker with full-width, multiline option labels, retaining the exact six tags, selection binding, semantic label and ordering. That removes the cramped label/value row and uses standard selection accessibility. It is not yet a justified shipped fix: compare actual AX5 full-app screenshots and selection/reselection, verify the entire longest English/Arabic option and VoiceOver selected state, then rerun the original audit without changing filters. A navigation-link picker is not automatically a solution because its collapsed selected value may still occupy a narrow trailing area. Do not shorten/omit choices or cap the font to silence the finding.

## Contrast

The identified Explore element's reported frame is y911.8–932.1, inside the tab-bar region y873–956 in this state. In the inspected Ask-before PNG, its text is indeed behind the floating tab material. That is a concrete viewport/overlap lead, not an established text-color defect or an exemption. The Form contains multiple screens of content; a proper check scrolls this existing control into the unobscured content region, verifies it remains reachable and opens its destination, and compares contrast there. Do not automatically scroll production or recolor all text based only on this image.

The three unidentified findings cannot safely be assigned to the disabled Ask/Repeat/map controls merely because those controls exist. Preserve them. A later bounded issue-image/metadata capture could increase the per-destination diagnostic limit from2 to5 with the overall image budget rebalanced; that would be a declared diagnostic variant, not a rerun of identical evidence limits. Do not add a broad unidentified/disabled contrast exemption.

No Ask production change has been made by this review.
