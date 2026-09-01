> 🤖 Written by AI --- read/modified by izkreny! 🤓

# Remove spec_helper's dead config block

Closes #213.

## Approach

Lines 49 to 93 of `spec/spec_helper.rb` are wrapped in `=begin` / `=end`, so the seven settings the RSpec generator suggested there have never executed. The generator writes them commented and expects the markers deleted once they have been read; they were never read. This deletes the markers and decides every setting individually, so what is left in the file is code that runs.

The load-bearing one is `config.order = :random`. `.agents/testing.md` states "No test interdependencies: the suite passes under any order", and today nothing enforces it, so the rule is an intention rather than a gate. Switching randomization on is what turns it into one, and `Kernel.srand config.seed` is what makes a failure reproducible from the seed the run prints.

Because the suite is already expected to pass in random order, this guard would go in green and stay green without ever having been seen to bite. So it is watched failing once, deliberately: an order dependency is introduced into a spec, a seed is found that catches it, and the change is reverted. A check never seen red proves nothing about the check.

## The seven settings, decided

| Setting | Verdict | Why |
|---|---|---|
| `config.filter_run_when_matching :focus` | live | `fit`/`fdescribe` become usable while debugging, and the failure mode that argues against it - a committed focus tag silently shrinking CI's suite to one example - is caught by `RSpec/Focus`, on by default under the `rubocop-rspec` plugin this repository loads in `.rubocop.yml`, on the required `lint` check. |
| `config.example_status_persistence_file_path` | deleted | The suite runs in about ten seconds, so `--only-failures` and `--next-failure` save nothing measurable, while the setting costs a `.gitignore` entry and a stale-prone state file in every checkout. Deferred to #216, not settled: the case returns if the suite gets slow. |
| `config.disable_monkey_patching!` | live | All 26 spec files already use `RSpec.describe`, none uses the `should` syntax, and no top-level `shared_examples` or `shared_context` exists, so the global monkey patches have no callers and closing them off costs nothing. |
| `config.default_formatter = "doc"` under `if config.files_to_run.one?` | live | #211 took `--format documentation` out of `.rspec`, which quieted single-file runs along with the full one. This gives the verbosity back exactly where it is wanted and nowhere else. |
| `config.profile_examples = 10` | deleted | It prints a slowest-examples block on every run, working directly against the quiet default #211 established. `bin/rspec --profile` gives it on demand. |
| `config.order = :random` | live | The only thing that can enforce the order-independence rule `.agents/testing.md` already states. |
| `Kernel.srand config.seed` | live | Seeds Ruby's own randomness from the run's seed, so a failure that depends on randomness is reproducible with `--seed`. Pointless without the setting above it. |

The generator's explanatory comment above each kept setting stays with it; a deleted setting takes its comment with it, so the file carries no commentary about code that is not there.

## Steps

- Delete the `=begin` and `=end` markers from `spec/spec_helper.rb`
- Delete `example_status_persistence_file_path` and `profile_examples`, with their comments
- Leave the other five live, each with its generator comment
- Watch the order guard fail once: introduce a deliberate order dependency between two examples, find a seed that catches it, revert it
- Run the suite on three seeds and fix, on this branch, any order dependency randomization exposes

## Verification

- [ ] `bin/rspec` prints a `Randomized with seed` line
- [ ] `bin/rspec --seed 12345`, `bin/rspec --seed 1` and `bin/rspec --seed 90210` all pass
- [ ] `bin/rspec spec/models/role_spec.rb` prints per-example names, while a full `bin/rspec` stays on progress dots
- [ ] A deliberately introduced order dependency fails under at least one seed, and passes again once reverted
- [ ] `bin/rubocop` reports an `RSpec/Focus` offense for a temporarily committed `fit`, and is clean once reverted
- [ ] `bin/ci` passes
- [ ] The `gh-solo` documentation check passes over this plan file
- [ ] `gh pr checks` green on `lint`, `scan_js`, `scan_ruby` and `test`

What those gates cannot see: three seeds are three samples, not a proof of order independence, so a dependency that only two specific files in one specific order trigger can still survive them. They also say nothing about whether `filter_run_when_matching :focus` is worth its risk, since the linter guard is a different check from the one that would notice a shrunken suite.

## Open questions

- Is `filter_run_when_matching :focus` worth keeping live? The guard against a committed `fit` is `RSpec/Focus` on the `lint` job, which is a linter noticing a tag rather than the runner noticing a suite that shrank from 479 examples to one. If that trade is not wanted, the setting is deleted like the other two and the file loses nothing else.
