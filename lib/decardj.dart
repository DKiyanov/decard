///Two types of files with appropriate extensions are supported:
///".decardj" - a text file in utf8 format containing data in json format as described below.

///".decardz" - a zip archive containing one or more files with the extension ".decardj" and media files
///all of which can be arranged in subdirectories within the archive
///The ".decardz" file (archive) cannot contain other ".decardz" files

///The json file has the following format:

class JsonFile{
	static const String title   = "title";   // the name of the file content
	static const String guid    = "GUID";    // it is used to search for the same files
	static const String version = "version"; // the integer, the version of the file, when rolling the update compare versions - the later one remains
	static const String author  = "author";  // author
	static const String site    = "site";    // site
	static const String email   = "email";   // email address
	static const String license = "license"; // license

	static const String cardStyleList    = "cardStyleList";    // list of card styles
  static const String qualityLevelList = "qualityLevelList"; // list of quality levels, used in card.upLinks
	static const String templateList     = "templateList";     // list of templates to generate cards
	static const String templatesSources = "templatesSources"; // the data for the templates
	static const String cardLis          = "cardList";         // list of cards
}

class JsonCardStyle { // cardStyleList element
	static const String id                         = "id";                         // string, style ID, unique within the file, used to reference the style from the card body
	static const String maxCost                    = "maxCost";                    // integer, the number of minutes earned if the answer is correct
	static const String minCost                    = "minCost";                    // integer, the number of minutes earned in the case of a correct answer
	static const String maxPenalty                 = "maxPenalty";                 // integer, the number of penalty minutes in case of NOT correct answer
	static const String minPenalty                 = "minPenalty";                 // integer, the number of penalty minutes in case of NOT correct answer
	static const String maxTryCount                = "maxTryCount";                // integer, the number of attempts at a solution in one approach
	static const String maxDuration                = "maxDuration";                // integer, seconds, the time allotted for the solution, default 1
	static const String minDuration                = "minDuration";                // integer, seconds, time allotted to solve, optional
	static const String lowDurationPercentCost     = "lowDurationPercentCost";     // integer, the lower value of the cost as a percentage of the current set cost, default 100
	static const String dontShowAnswer             = "dontShowAnswer";             // boolen, default false, do NOT show in case of a wrong answer
	static const String answerVariantList          = "answerVariantList";          // list of answer choices
	static const String answerVariantCount         = "answerVariantCount";         // Number of answer choices displayed
	static const String answerVariantListRandomize = "AnswerVariantListRandomize"; // boolean, default false, randomize the list
	static const String answerVariantMultiSel      = "answerVariantMultiSel";      // boolean, multiple answers can/should be selected (in the interface, selectable buttons + check result button "Done")
	static const String answerInputMode            = "answerInputMode";            // string, fixed value set, see cardStyle.answerInputMode enumeration below
	static const String widgetKeyboard             = "widgetKeyboard";             // virtual keyboard: list of buttons on the keyboard, buttons can contain several characters, button delimiter symbol "\t" string translation "\n"
}
