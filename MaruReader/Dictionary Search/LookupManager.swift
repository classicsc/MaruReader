//
//  LookupManager.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/16/25.
//

/// Performs lookups against the Core Data store, groups and sorts candidates.
/// To minimize the number of fetch requests, LookupResult objects should be returned
/// by an iterator. We'll keep track of ranked LookupCandidates and only fetch
/// the corresponding LookupResults when requested.
/// Results are ranked according to the following rules in order of priority:
///  1. Source term length - longer originalSubstring candidates ranked higher
///  2. Text processing chain length (preprocessorRules) - shorter processing chains ranked higher
///  3. Inflection chain length (deinflectionRules) - shorter inflection chains ranked higher
///  4. Source term exact match - candidates with more exact matches to deinflections ranked higher
///  5. Frequency order - candidates with higher frequency values according to the user's selected frequency dictionary ranked higher. Note that the "highest frequency" is the lowest number when the frequency dictionary's frequencyMode is "rank-based" and the highest number when it is "occurrence-based".
///  6. Dictionary order - terms from dictionaries ranked higher in user preferences ranked higher
///  7. Term score - higher term scores ranked higher. Only applies when the terms under
///  comparison have a score assigned by the same dictionary.
///  8. Expression text - alphabetical comparison
///  9. Definition count - more definitions ranked higher
///
/// Rules 1-4 and 8 are properties of the LookupCandidate and are applied during candidate generation.
/// Rule 5 requires fetching frequency values from TermMeta entities.
/// Rules 6-7 and 9 require fetching Term entities.
