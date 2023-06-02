///Two types of files with appropriate extensions are supported:
///".decardj" - a text file in utf8 format containing data in Djf format as described below.

///".decardz" - a zip archive containing one or more files with the extension ".decardj" and media files
///all of which can be arranged in subdirectories within the archive
///The ".decardz" file (archive) cannot contain other ".decardz" files

///The json file has the following format:

class DjfFile{
	static const String formatVersion    = "formatVersion";    // TODO format version
	static const String title            = "title";            // the name of the file content
	static const String guid             = "GUID";             // it is used to search for the same files
	static const String version          = "version";          // integer, the version of the file, when rolling the update compare versions - the later one remains
	static const String author           = "author";           // author
	static const String site             = "site";             // site
	static const String email            = "email";            // email address
	static const String license          = "license";          // license

	static const String cardStyleList    = "cardStyleList";    // array of DjfCardStyle
	static const String qualityLevelList = "qualityLevelList"; // array of DjfQualityLevel
	static const String templateList     = "templateList";     // array of DjfCardTemplate
	static const String templatesSources = "templatesSources"; // array of DjfTemplateSource
	static const String cardList         = "cardList";         // array of DjfCard
}

class DjfCardStyle { // cardStyleList element
	static const String id                         = "id";                         // string, style ID, unique within the file, used to reference the style from the card body
	static const String maxCost                    = "maxCost";                    // integer, the number of minutes earned if the answer is correct
	static const String minCost                    = "minCost";                    // integer, the number of minutes earned in the case of a correct answer
	static const String maxPenalty                 = "maxPenalty";                 // integer, the number of penalty minutes in case of NOT correct answer
	static const String minPenalty                 = "minPenalty";                 // integer, the number of penalty minutes in case of NOT correct answer
	static const String maxTryCount                = "maxTryCount";                // integer, the number of attempts at a solution in one approach
	static const String maxDuration                = "maxDuration";                // integer, seconds, the time allotted for the solution, default 1
	static const String minDuration                = "minDuration";                // integer, seconds, time allotted to solve, optional
	static const String lowDurationPercentCost     = "lowDurationPercentCost";     // integer, the lower value of the cost as a percentage of the current set cost, default 100
	static const String dontShowAnswer             = "dontShowAnswer";             // boolean, default false, do NOT show in case of a wrong answer
	static const String answerVariantList          = "answerVariantList";          // list of answer choices
	static const String answerVariantCount         = "answerVariantCount";         // Number of answer choices displayed
	static const String answerVariantListRandomize = "AnswerVariantListRandomize"; // boolean, default false, randomize the list
	static const String answerVariantMultiSel      = "answerVariantMultiSel";      // boolean, multiple answers can/should be selected (in the interface, selectable buttons + check result button "Done")
	static const String answerInputMode            = "answerInputMode";            // string, fixed value set, see cardStyle.answerInputMode enumeration below
	static const String answerCaseSensitive        = "answerCaseSensitive";        // TODO boolean, answer is case sensitive
	static const String widgetKeyboard             = "widgetKeyboard";             // virtual keyboard: list of buttons on the keyboard, buttons can contain several characters, button delimiter symbol "\t" string translation "\n"
	static const String introductoryCount          = "introductoryCount";          // TODO the number of impressions at the beginning of the study without penalty
	static const String imageMaxHeight             = "imageMaxHeight";             // TODO Maximum image height as a percentage of the screen height
	static const String notShowIfLearned           = "notShowIfLearned";           // TODO Do not show if the card is learned
}

class DjfAnswerInputMode {
	static const String none           = "none";           // input method is not defined
	static const String ddList         = "ddList";         // Drop down list
	static const String vList          = "vList";          // vertical list
	static const String hList          = "hList";          // Horizontal list
	static const String input          = "input";          // random input field
	static const String inputDigit     = "inputDigit";     // Field for random numeric input
	static const String widgetKeyboard = "widgetKeyboard"; // virtual keyboard: list of buttons on the keyboard, buttons can contain several characters, button separator symbol "\t" string translation "\n"
}

class DjfQualityLevel {
	static const String qualityName = "qlName";     // the name of the quality level
	static const String minQuality  = "minQuality"; // minimum quality
	static const String avgQuality  = "avgQuality"; // medium quality
}

class DjfCardTemplate {
	static const String templateName = "tName"; // template name
	
	// one or more card templates
	// The card template is written exactly the same way as a normal card
	// only these fields may contain characters <@field name source@> these characters are replaced with the corresponding value from source
	static const String cardTemplateList = "cardTemplateList"; 
}

class DjfTemplateSource {
	static const String templateName = DjfCardTemplate.templateName; // template name

	static const String paramBegin = "<@";
	static const String paramEnd   = "@>";
}

class DjfCard { // element of DjfFile.cardList 
	static const String id       = "id";       // string, unique identifier of the card within the file
	static const String title    = "title";    // title
	static const String group    = "group";    // string, name of the group of cards
	static const String tags     = "tags";     // array of card tags
	static const String upLinks  = "upLinks";  // array of DjfUpLink, links to the cards to be studied earlier (predecessors)
	static const String bodyList = "bodyList"; // array of DjfCardBody
}

class DjfUpLink { // element of DjfCard.upLinks 
	static const String qualityName    = "qlName"; // string, DjfQualityLevel.qualityName
	static const String tags           = "tags";   // array of tags from predecessor cards
	static const String cards          = "cards";  // array DjfCard.id
	static const String groups         = "groups"; // array DjfCard.group

	static const String cardTagPrefix  = "id@";    // prefix for make tag from card.id
	static const String groupTagPrefix = "grp@";   // prefix for make tag from card.group
}

class DjfQuestionData { // question data
	static const String text     = "text";     // optional, string, question text
	static const String html     = "html";     // optional, string, html with question
	static const String markdown = "markdown"; // TODO optional, string, markdown with question
	static const String audio    = "audio";    // optional, link to audio resource
	static const String video    = "video";    // optional, link to video resource
	static const String image    = "image";    // optional, link to image
}

class DjfCardBody { // element of DjfCard.bodyList
	static const String styleIdList  = "styleIdList";  // array of DjfCardStyle.id
	static const String style        = "style";        // embedded structure DjfCardStyle
	static const String questionData = "questionData"; // embedded structure DjfQuestionData
	static const String answerList   = "answerList";   // array of answer values
	static const String audioOnRightAnswer = "audioOnRightAnswer"; // TODO array of path to audio file
	static const String audioOnWrongAnswer = "audioOnWrongAnswer"; // TODO array of path to audio file
}
