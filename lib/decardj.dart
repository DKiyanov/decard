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

	static const String cardStyleList    = "cardStyleList";    // array of JsonCardStyle
        static const String qualityLevelList = "qualityLevelList"; // array of JsonQualityLevel
	static const String templateList     = "templateList";     // array of JsonCardTemplate
	static const String templatesSources = "templatesSources"; // array of JsonTemplateSource
	static const String cardLis          = "cardList";         // array of JsonCard
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

class JsonQualityLevel {
	static const String qualityName = "qlName";     // the name of the quality level
	static const String minQuality  = "minQuality"; // minimum quality
	static const String avgQuality  = "avgQuality"; // medium quality
}

class JsonCardTemplate
{
	static const String templateName = "templateName"; // template name
	
	// one or more card templates
	// The card template is written exactly the same way as a normal card
	// only these fields may contain characters <@field name source@> these characters are replaced with the corresponding value from source
	static const String cardTemplateList = "cardTemplateList"; 
}

class JsonTemplateSource {
	static const String templateName = "templateName"; // template name
}

class JsonCard { // element of JsonFile.cardList 
	static const String id       = "id";       // string, unique identifier of the card within the file
	static const String title    = "title";    // title
	static const String group    = "group";    // string, name of the group of cards
        static const String tags     = "tags";     // array of card tags
        static const String upLinks  = "upLinks";  // array of JsonUpLink, links to the cards to be studied earlier (predecessors)
	static const String bodyList = "bodyList"; // array of JsonCardBody
}

class JsonUpLink { // element of JsonCard.upLinks 
	static const String qualityName = "qlName"; // string, JsonQualityLevel.qualityName
	static const String tags        = "tags";   // array of tags from predecessor cards
	static const String cards       = "cards";  // array JsonCard.id
	static const String groups      = "groups"; // array JsonCard.group
}

class JsonQuestionData { // question data
	static const String text  = "text";  // optional, string, question text
	static const String html  = "html";  // optional, string, html with question
	static const String audio = "audio"; // optional, link to audio resource		
	static const String video = "video"; // optional, link to video resource
	static const String image = "image"; // optional, link to image
}

class JsonCardBody { // element of JsonCard.bodyList
	static const String styleIdList  = "styleIdList";  // array of JsonCardStyle.id
	static const String style        = "style";        // embedded structure JsonCardStyle
	static const String questionData = "questionData"; // embedded structure JsonQuestionData
	static const String answerList   = "answerList";   // array of answer values
}
