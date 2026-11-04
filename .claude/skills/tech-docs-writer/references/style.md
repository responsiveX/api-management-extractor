# House Style

These rules control tone, person, word choice, and document shape. `simplified-technical-english.md` controls the sentence: its length, verb forms, and voice. If the two files seem to conflict, STE controls the sentence and this file controls everything else.

When you are not sure, use the version that is shorter and more concrete.

## Person

**Use the third person by default.** Do not write "we" or "I". The document describes the system, not the authors.

- ❌ "We use Postgres because we need strong consistency."
- ✅ "The service uses Postgres because it needs strong consistency."

- ❌ "You can think of the cache as a shortcut."
- ✅ "The cache stores recent query results, so the service does not query the database again."

**In How-to and Tutorial documents, address the reader.** Use the imperative for steps. Use "you" where a sentence needs a subject, for example to describe what the reader will see.

- ✅ "Run `make migrate`. The terminal shows `Migrations complete`."
- ✅ "If you use a local database, skip step 4."

## Tone

**Keep the tone neutral.** Do not use marketing words, exhortations, or rhetorical questions. A neutral tone lets the reader trust each sentence as a fact.

- ❌ "This powerful and flexible API makes it easy to build amazing integrations."
- ✅ "The API exposes create, read, update, and delete operations for the core resources."

- ❌ "Don't forget to close the connection!"
- ✅ "The caller must close the connection."

- ❌ "Have you ever wondered how the scheduler picks jobs?"
- ✅ "The scheduler picks jobs by priority, then by submission time."

**Do not editorialize.** Words such as "elegant", "unfortunately", and "surprisingly" are opinions. A reader wants the fact. If a trade-off matters, state it as a fact in the Explanation document.

**Hedge only when the uncertainty is real.** "Might", "perhaps", and "it seems" tell the reader that the author does not know. Use them only when the behavior of the subject really is variable. Then say what it depends on.

- ❌ "The job might take a while."
- ✅ "The job takes between 2 and 10 minutes, depending on the number of pending orders."

## Plain words

**Use the common word.** These substitutions also agree with the STE principle of one simple word for one meaning.

| Do not use | Use |
|---|---|
| utilize, leverage | use |
| facilitate | help, let |
| initiate, commence | start |
| terminate | stop, end |
| prior to | before |
| subsequent to | after |
| in order to | to |
| a plethora of | many, several, or the number |
| functionality | feature, function |
| methodology | method |
| ensure | make sure |
| via | through, with, by |

**Remove filler.** Remove each word that adds no information.

- ❌ "Basically, the function essentially just returns the first matching record."
- ✅ "The function returns the first matching record."

**Replace a vague quantifier with a value, or remove it.** "Fast", "many", "large", and "some" do not tell the reader anything that they can use.

- ❌ "The cache stores a large number of entries."
- ✅ "The cache stores up to 10,000 entries."
- ✅ (if the number is not important) "The cache has a size limit. When the cache is full, it removes the least recently used entry."

- ❌ "The operation is fast."
- ✅ "The operation completes in less than 50 ms at p99."

## Words to remove

- "Simply", "just", and "easily". These words tell a reader who has a problem that the task is easy. They never add information.
- "Note that", "it's worth noting", and "as mentioned". If the fact is important, state it.
- "Obviously", "clearly", and "of course". If the fact were obvious, the document would not need it.
- Exclamation points and rhetorical questions.

## Lists

**Use a list when the items are parallel and you can count them.** Use prose when each item depends on the one before it.

**Make the list items parallel in structure.** All items start with a verb, or all items are noun phrases.

- ❌
  - Validates the input
  - Authentication
  - It writes to the log
- ✅
  - Validates the input
  - Authenticates the caller
  - Writes to the log

## Headings

**Make headings descriptive.** A reader who scans the headings must know what each section contains. A clever heading hides the content.

- ❌ "The Magic Behind the Scheduler"
- ✅ "Scheduler algorithm"

- ❌ "Getting Your Hands Dirty"
- ✅ "Running the service locally"

## Punctuation

**Do not use a pair of em-dashes for an aside or a list of examples.** An em-dash pair interrupts the main sentence. Introduce the examples with "such as" or "including", or write a second sentence.

- ❌ "Adding a third consumer — an analytics pipeline, a cache invalidator, an audit log — requires no change to the publisher."
- ✅ "A new consumer, such as an analytics pipeline or an audit log, needs no change to the publisher."

- ❌ "The broker — Kafka, RabbitMQ, or NATS — retains undelivered events."
- ✅ "The broker keeps events that are not delivered. Kafka, RabbitMQ, and NATS are common brokers."

**Use a single em-dash at the end of a sentence only rarely.** A period and a new sentence is usually clearer.

**Do not use semicolons to join two facts.** Write two sentences. This also keeps each sentence to one topic, as STE requires.
