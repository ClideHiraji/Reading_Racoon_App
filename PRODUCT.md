# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

This record covers the learner game only. The teacher dashboard and the admin portal (web) are separate surfaces with their own record later.

- **Grade 1 learners (6–7 years old) at Ampayon Elementary School, Butuan City, Agusan del Norte.** 62 children in two sections take part in the study, with written parental consent:
  - **Advanced section** (Teacher Irish Delgado, 36 learners, all functional readers) plays **at school on 3 shared Windows laptops with a mouse**, about 12 children to a laptop.
  - **Regular section** (Teacher Estremos, 26 learners, about 16 functional readers, 3 in ARAL Basic) plays **on their parents' phones, Android and iPhone**. Many of these children face poverty, absenteeism and little help with reading at home; they have low confidence, fear mistakes, and some cry when phonics gets hard.
- **Their job:** play short reading tasks (sounds, letters, words, stories) while the game quietly measures how well they read, then practise, read books and sing along in the free-play sections.
- **Teachers** reach into the game only through settings they control (class schedule, roster, opening the post-test, picking books and videos); they read results on the web dashboard.

## Product Purpose

Reading Racoon assesses Grade 1 reading comprehension through play ("stealth assessment") instead of the manual Phil-IRI / EGRA tests that burden teachers and make young children anxious. It tracks mastery of five MATATAG reading sub-skills with Bayesian Knowledge Tracing (BKT) and moves each child up when mastery reaches 0.95, keeping them at the right challenge; the data feeds AI-written reports for the teacher.

It is a capstone thesis (BSIT, Caraga State University – Main Campus; King Clide R. Jagape and Sophia Lhyn A. Guhiting), due November 2026. Success means: a significant gain from pre-test to post-test over the evaluation period, teachers and IT professionals rating it useful and easy to use (TAM survey), and children who keep playing without fear of getting things wrong.

## Positioning

Assessment that a child experiences as a storybook adventure: every answer silently updates the child's mastery per sub-skill, mistakes earn a question-specific hint and a second try instead of a grade, and the companion Racoon cheers them on. It runs offline on whatever device the child has, in the child's languages, set in the child's own city.

## Operating Context

- **Two very different scenes.** At school, children take turns on a few shared laptops in landscape, with a mouse, a teacher in the room and the class schedule in force. Outside school, a child borrows a parent's phone in portrait, by touch, on mobile data or none.
- **Shared devices:** each child signs in with a code and has their own profile on the device; "Switch student" hands it to the next child once their progress is uploaded (D-010).
- **Unreliable internet:** everything plays offline and syncs automatically when a connection returns (FR-11, D-008); teacher books and videos download only on Wi-Fi (D-020).
- **Time rules (FR-12, D-015):** Adventure follows the teacher's class window; free play (Practice, Library, Watch & Listen) has a daily allowance; the game rests at night and on weekends by default.
- **The study's rhythm:** a pre-test ("Reading Adventure") before lessons open, about four months of play, then a post-test ("Big Reading Day") the teacher opens; a TAM survey of 2 Grade 1 teachers and 3 IT professionals, plus a classroom observation checklist.

## Capabilities and Constraints

- **Built with Godot 4.7 and GDScript**, one codebase exported to **Android and iOS phones and Windows laptops**; the layout is portrait 720×1280. Backend: Laravel + PostgreSQL + Sanctum (no Firebase); the LLM (Google Gemini) is called only from Laravel.
- **Learning loop:** pre-test → adaptive lessons over five sub-skills (phonological awareness, phonics, vocabulary, fluency, literal comprehension) across five levels → teacher-opened post-test. Two tries per question with a hint; only the first try counts as BKT evidence (D-021). Three hearts: one lost per wrong try, one back per right answer, and Racoon's Rescue at zero (FR-13, D-004, D-021). Nothing from an unfinished lesson is saved.
- **Rewards and free play:** stars, coins and stickers; coins buy cosmetics for Racoon in the Closet (FR-07); daily goals; Practice games, a Library of read-along books and Watch & Listen songs and videos, none of which affect BKT (D-017).
- **Read aloud:** prompts, stories and feedback are spoken (FR-20); the child taps to hear again.
- **Requirements:** BKT update within 500 ms (NFR-01); touch targets at least 48×48 dp and text at least 24 pt (NFR-02); RA 10173 Data Privacy Act compliance for minors, with anonymized student codes (NFR-04). Device floor: Android 8 / iOS 13, 2 GB RAM, 720p screen.
- **Languages:** Mother Tongue for levels 1–2, Filipino for 3–4, English for 5 (MATATAG bridge). Current lesson content is English placeholder text awaiting teacher review.
- **Open decisions:**
  - How the portrait layout and touch-first controls work on landscape laptop screens with a mouse.
  - Where and when the regular section plays on parents' phones (at home, after school, with a parent nearby?).
  - Which Mother Tongue levels 1–2 use (open issue 15).
  - Racoon's redesign (options exist; not chosen).
  - The evaluation timeline against the November deadline (open issue 11).

## Brand Commitments

- **Name:** Reading Racoon. The companion is called **Racoon** in the game (the thesis spells it "raccoon").
- **Racoon** is a friendly companion who gives short, positive, on-task hints and encouragement, and never open-ended social chat: 6–7-year-olds can attach strongly to an AI character. Children customize Racoon with the cosmetics they earn.
- **Set in Butuan:** the adventure's worlds are local places (Agusan River, Mango Grove, Bahay Kubo Village, Balangay Bay, Mount Mayapay) (D-009).
- **No comparison between children:** no leaderboards, no competition, no streak guilt, no red ✗ for a wrong answer; rewards are personal (D-007).

## Evidence on Hand

- The thesis manuscript (Chapters 1–3), distilled in `docs/knowledge/`, including the teacher interviews with Teacher Delgado and Teacher Estremos.
- Decisions D-001 to D-022 in `brain/decisions/`.
- Lesson, test and library content in `reading-racoon/content/*.json` (placeholders pending teacher review).
- The team's Lottie animations (earned star, regained heart, broken heart) in `reading-racoon/assets/anim/lottie/`.
- **Not yet available, and not to be invented:** learner results (the evaluation hasn't run), quotes or testimonials from teachers, parents or children, final Mother Tongue content.

## Product Principles

1. **The child's confidence comes first.** When a child's feelings, assessment precision and teacher convenience pull apart, protect the child: no visible test grades during play, a hint and a second try after a mistake, a heart back with every right answer.
2. **Assessment hides inside play.** Measure through ordinary tasks; even the pre-test and post-test are framed as an adventure, never as a test.
3. **It works for a child on their own.** Nothing may depend on reading ability, help at home, a particular device or a working internet connection; every instruction is spoken.
4. **Progress is personal.** Children are only ever compared with their own earlier selves.
5. **Teachers stay in charge.** The AI supports the teacher's judgment (reports, flags) and never replaces it; teachers set when children play and what they read.

## Accessibility & Inclusion

- **Pre-readers and emerging readers:** spoken instructions, pictures and icons before words, and navigation that needs no reading.
- **Young hands and eyes:** NFR-02 sizes, and 3–5 choices per screen at most.
- **Anxious learners:** gentle, specific feedback with no punishment for mistakes.
- **Mouse users:** on the school laptops every control must work as well with a mouse as with a finger.
- **Shared devices and minors' data:** profiles stay separate, and privacy follows RA 10173.
