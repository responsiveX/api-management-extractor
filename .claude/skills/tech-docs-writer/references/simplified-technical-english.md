# Simplified Technical English

Simplified Technical English (STE) is a controlled language. Its standard is ASD-STE100. The aerospace industry made STE for maintenance manuals, where a misread instruction can cause an accident. STE has two parts: a set of writing rules, and a dictionary of approved words, each with one meaning. The dictionary is not included in the skill and should be followed in spirit rather than literally.

This skill applies the writing rules and the principle of one word for one meaning. It does not restrict the vocabulary to the STE dictionary. Software documentation needs technical names that are not in that dictionary, and the dictionary is licensed material. The rules below are a paraphrase for software documentation, not a copy of the standard.

STE is good for software documentation for the same reasons as for manuals. Many readers of the documents speak English as a second language. Machine translation of STE text is more accurate. A short sentence with one meaning is also faster for a native speaker who scans a page for one fact.

## Contents

- Scope: what STE applies to
- Words
- Noun clusters
- Verbs
- Sentences
- Procedural writing
- Descriptive writing
- Warnings and cautions

## Scope: what STE applies to

STE applies to prose: paragraphs, list items, table descriptions, and captions. It does not apply to these items:

- Code, command lines, and Mermaid blocks.
- Identifiers, file paths, and configuration keys, such as `MaxRetryCount` or `appsettings.json`.
- Product and service names, such as Azure Service Bus or Cosmos DB.
- Error messages and UI labels that you quote exactly.

Count each identifier or product name as one word in a sentence.

## Words

**Use one word for one meaning.** Select one term for each concept and use only that term. If the document calls it a "worker", do not also call it a "consumer", a "processor", and a "job runner". A reader who sees a new word thinks that it is a new thing.

- ❌ "The service publishes an event. The consumer receives the message and processes the notification."
- ✅ "The service publishes an event. The consumer receives the event and processes it."

**Use a word with its most common meaning.** "Run" means to execute. Do not also use "run" to mean "a sequence" in the same document.

**Use the simple word.** Use "start", not "initiate". Use "stop", not "terminate". Use "use", not "utilize". The table of preferred words is in `style.md`.

**Define project terms on first use.** A term that is special to the project, or a word used with a special meaning, needs a definition. Define it the first time it appears.

- ✅ "A *tenant* is one operator location with its own data partition."

**Do not use phrasal verbs when a single verb is available.** Phrasal verbs are difficult for non-native readers and for machine translation.

- ❌ "Set up the database, then fill in the connection string."
- ✅ "Create the database. Then write the connection string in `appsettings.json`."

Technical phrasal verbs that have no single-word equivalent, such as "log in" and "check out a branch", are acceptable.

## Noun clusters

**Do not write a noun cluster of more than three words.** A noun cluster is a sequence of nouns that modify each other. A long noun cluster hides the relations between the words.

- ❌ "the order sync retry policy configuration value"
- ✅ "the value that sets the retry policy for order sync"

Identifiers are one word. "The `OrderSyncOptions` value" is a cluster of two words.

## Verbs

**Use only these verb forms:**

- The imperative: "Run the migration."
- The simple present: "The worker reads the queue."
- The simple past: "The deployment failed."
- The simple future: "The job will retry at 02:00."
- The infinitive: "Use the script to reset the database."
- The past participle as an adjective only: "the cached value", "a deleted record".

Do not use the progressive or perfect forms, such as "is running", "has completed", or "will have been sent".

- ❌ "The worker is reading from the queue and has processed the first batch."
- ✅ "The worker reads from the queue. It processed the first batch."

**Use the active voice.** Use the passive voice in descriptive writing only when the actor is unknown, or when the actor does not matter to the reader. Do not use the passive voice in procedures.

- ❌ "The request is validated by the middleware."
- ✅ "The middleware validates the request."
- ✅ "Requests are rate-limited at 100 per minute." (The reader does not need to know which component applies the limit.)

**Use an "-ing" word only as a noun or as part of a technical name.** "The logging middleware" and "load balancing" are acceptable. "When receiving a request, the handler..." is not acceptable, because the "-ing" clause has no clear subject.

- ❌ "After validating the token, the claims are attached to the request."
- ✅ "The middleware validates the token. Then it attaches the claims to the request."

Headings can use an "-ing" form, such as "Running the service locally". Headings are labels, not sentences.

**Use an action verb, not a noun made from a verb.**

- ❌ "Perform a restart of the service."
- ✅ "Restart the service."

## Sentences

**Keep one topic in each sentence.** Put a second fact in a second sentence.

- ❌ "The scheduler, which replaced the cron system in v2.0, picks jobs by priority but can also pick by submission time, and it runs every 30 seconds."
- ✅ "The scheduler picks jobs by priority. A configuration setting changes the order to submission time. The scheduler runs every 30 seconds."

**Do not remove words to make a sentence shorter.** Keep the articles ("a", "an", "the"), the subject, and the verb. Telegraphic text is short but ambiguous.

- ❌ "Check config before deploy."
- ✅ "Check the configuration before you deploy."

The exception is table cells and short list labels, where fragments are normal.

**Put the subject first.** A reader must know what the sentence is about before the details arrive.

- ❌ "When a request comes in, after it passes the rate limiter and the authenticator, the handler receives it."
- ✅ "The handler receives a request after the request passes the rate limiter and the authenticator."

**Use a vertical list for complex text.** When a sentence contains three or more conditions, steps, or items, write them as a list.

**Every pronoun needs a clear antecedent.** If "it" can refer to two nouns, repeat the noun.

- ❌ "The worker reads from the queue and writes to the store. It also logs errors."
- ✅ "The worker reads from the queue and writes to the store. The worker also logs errors."

## Procedural writing

Procedural writing tells the reader what to do. It occurs in How-to and Tutorial documents, and in any step list.

- **Write 20 words or fewer in each sentence.**
- **Write one instruction in each sentence.** Two actions can be in one sentence only if the reader does them at the same time.
- **Use the imperative.** Start the step with the verb.
- **Put a condition before the instruction.** The reader must know the condition before the reader acts.
- **Write a separate step for the result.** Tell the reader what they will see when the step is correct, so they can confirm it before they continue.

- ❌ "You should now go ahead and run the migration, which will update the schema, and then restart the API."
- ✅
  1. Run the migration: `dotnet ef database update`.
  2. Restart the API.

- ❌ "Run the seed script if the database is new."
- ✅ "If the database is new, run the seed script."

## Descriptive writing

Descriptive writing tells the reader how something is or how it works. It occurs in Reference and Explanation documents.

- **Write 25 words or fewer in each sentence.**
- **Keep one topic in each paragraph.** Start the paragraph with a sentence that states the topic.
- **Write six sentences or fewer in each paragraph.**
- **Use connecting words to show the relation between sentences.** Words such as "then", "because", "but", and "as a result" help the reader follow a sequence of facts.

- ❌ "The cache stores recent results. The TTL is 5 minutes. Deployments clear it. The key includes the tenant ID."
- ✅ "The cache stores query results for 5 minutes. Each cache key includes the tenant ID, so tenants never share results. A deployment clears the cache."

## Warnings and cautions

A warning tells the reader about a risk of data loss, outage, or a security problem. A caution tells the reader about a risk of damage to a system that can be repaired.

- Put the warning before the step that it applies to. A reader who acts on the step first can cause the damage before the reader sees the warning.
- Start with a clear command, then give the reason.
- Do not use a warning for general advice. Too many warnings teach the reader to ignore them.

- ❌ "Run `db-reset`. Note that this deletes all local data."
- ✅
  > **Warning:** Export your local test data before you continue. The next step deletes all data in the local database.

  3. Run `db-reset`.
