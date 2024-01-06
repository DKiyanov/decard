///Two types of files with appropriate extensions are supported:
///".decardj" - a text file in utf8 format containing data in json format as described below.

///".decardz" - a zip archive containing one file with the extension ".decardj" in the root and media files
///all of which can be arranged in subdirectories within the archive
///The ".decardz" file (archive) cannot contain other ".decardz" files
///The following optional filenames int the root of archive are reserved:
///  thumbnail.png - picture to represent the file
///  icon.png - small picture to represent the file
///  license.txt - full text of the license, used if the license is not standard
///  readme.md - detailed description of the package

///The json file has the following format:

class DjfFileExtension{
	static const String json = ".decardj";
	static const String zip  = ".decardz";
	static const values = [json, zip];
}

class DjfFile{ // top json file structure
	static const String formatVersion    = "formatVersion";    // TODO format version
	static const String title            = "title";            // the name of the file content
	static const String guid             = "GUID";             // it is used to search for the same files
	static const String version          = "version";          // integer, the version of the file, when rolling the update compare versions - the later one remains
	static const String author           = "author";           // author
	static const String site             = "site";             // site
	static const String email            = "email";            // email address
	static const String tags             = "tags";             // string list of tags, separator ","
	static const String license          = "license";          // license
	static const String targetAgeLow     = "targetAgeLow";     // target age low
	static const String targetAgeHigh    = "targetAgeHigh";    // target age high

	static const String cardStyleList    = "cardStyleList";    // array of DjfCardStyle
	static const String qualityLevelList = "qualityLevelList"; // array of DjfQualityLevel
	static const String templateList     = "templateList";     // array of DjfCardTemplate
	static const String templatesSources = "templatesSources"; // array of DjfTemplateSource
	static const String cardList         = "cardList";         // array of DjfCard
}

class DjfCardStyle { // DjfFile.cardStyleList element
	static const String id                         = "id";                         // string, style ID, unique within the file, used to reference the style from the card body
	static const String dontShowAnswer             = "dontShowAnswer";             // boolean, default false, do NOT show answer in case of a wrong answer
	static const String dontShowAnswerOnDemo       = "dontShowAnswerOnDemo";       // boolean, default false, do NOT show answer in demo mode on child device
	static const String answerVariantList          = "answerVariantList";          // list of answer choices
	static const String answerVariantCount         = "answerVariantCount";         // Number of answer choices displayed
	static const String answerVariantListRandomize = "answerVariantListRandomize"; // answer text align, values string left, right, center
	static const String answerVariantAlign         = "answerVariantAlign";         // boolean, default false, randomize the list
	static const String answerVariantMultiSel      = "answerVariantMultiSel";      // boolean, multiple answers can/should be selected (in the interface, selectable buttons + check result button "Done")
	static const String answerInputMode            = "answerInputMode";            // string, fixed value set, see cardStyle.answerInputMode enumeration below
	static const String answerCaseSensitive        = "answerCaseSensitive";        // boolean, answer is case sensitive
	static const String widgetKeyboard             = "widgetKeyboard";             // virtual keyboard: list of buttons on the keyboard, buttons can contain several characters, button delimiter symbol "\t" string translation "\n"
	static const String imageMaxHeight             = "imageMaxHeight";             // Maximum image height as a percentage of the screen height
	static const String buttonImageWidth           = "buttonImageWidth";           // Maximum button image width  as a percentage of the screen width
	static const String buttonImageHeight          = "buttonImageHeight";          // Maximum button image height as a percentage of the screen height
	
	static const String buttonImagePrefix          = "img=";                       // Prefix for button image: img=<file path>
}

class DjfAnswerInputMode { // values for DjfCardStyle.answerInputMode
	static const String none           = "none";           // input method is not defined
	static const String ddList         = "ddList";         // Drop down list
	static const String vList          = "vList";          // vertical list
	static const String hList          = "hList";          // Horizontal list
	static const String input          = "input";          // random input field
	static const String inputDigit     = "inputDigit";     // Field for random numeric input
	static const String widgetKeyboard = "widgetKeyboard"; // virtual keyboard: list of buttons on the keyboard, buttons can contain several characters, button separator symbol "\t" string translation "\n"
}

class DjfQualityLevel { // element of DjfCardStyle.qualityLevelList
	static const String qualityName = "qlName";     // the name of the quality level
	static const String minQuality  = "minQuality"; // minimum quality
	static const String avgQuality  = "avgQuality"; // medium quality
}

class DjfCardTemplate { // element of DjfCardStyle.templateList
	static const String templateName = "tName"; // template name
	
	// one or more card templates
	// The card template is written exactly the same way as a normal card
	// only these fields may contain characters <@field name source@> these characters are replaced with the corresponding value from DjfTemplateSource
	static const String cardTemplateList = "cardTemplateList"; 
}

class DjfTemplateSource { // element of DjfCardStyle.templatesSources
	static const String templateName = DjfCardTemplate.templateName; // template name

	// contains other fields for substitution in the template, at the discretion of the user
	
	static const String paramBegin = "<@";
	static const String paramEnd   = "@>";
}

class DjfCard { // element of DjfFile.cardList 
	static const String id         = "id";         // string, unique identifier of the card within the file
	static const String title      = "title";      // title
	static const String difficulty = 'difficulty'; // difficulty
	static const String group      = "group";      // string, name of the group of cards
	static const String tags       = "tags";       // array of card tags
	static const String upLinks    = "upLinks";    // array of DjfUpLink, links to the cards to be studied earlier (predecessors)
	static const String bodyList   = "bodyList";   // array of DjfCardBody
	static const String notShowIfLearned  = "notShowIfLearned";           // TODO Do not show if the card is learned
	static const String help       = "help"; // optional, local path to html/markdown file, file can be a template
}

class DjfUpLink { // element of DjfCard.upLinks 
	static const String qualityName    = "qlName"; // string, DjfQualityLevel.qualityName
	static const String tags           = "tags";   // array of tags from predecessor cards
	static const String cards          = "cards";  // array DjfCard.id
	static const String groups         = "groups"; // array DjfCard.group

	static const String cardTagPrefix  = "id@";    // prefix for make tag from card.id
	static const String groupTagPrefix = "grp@";   // prefix for make tag from card.group
}

class DjfQuestionData { // structure of DjfCardBody.questionData
	static const String text     = "text";     // optional, string, question text
	static const String html     = "html";     // optional, local path to html file, file can be a template
	static const String markdown = "markdown"; // optional, local path to markdown file, file can be a template
	static const String textConstructor = "textConstructor"; // optional, local path to text constructor json file, file can be a template
	static const String audio    = "audio";    // optional, local path to audio resource
	static const String video    = "video";    // TODO optional, url/local path to video resource
	static const String image    = "image";    // optional, local path to image
}

class DjfCardBody { // element of DjfCard.bodyList
	static const String styleIdList  = "styleIdList";  // array of DjfCardStyle.id
	static const String style        = "style";        // embedded structure DjfCardStyle
	static const String questionData = "questionData"; // array with source with data for question
	static const String answerList   = "answerList";   // array of answer values
	static const String audioOnRightAnswer = "audioOnRightAnswer"; // TODO optional, link to audio resource
	static const String audioOnWrongAnswer = "audioOnWrongAnswer"; // TODO optional, link to audio resource
	static const String clue = "clue"; // optional, local path to html/markdown file, file can be a template
}

/// DjfCardBody.questionData:
/// each row of the array contains a separate resource for forming a question
/// it could be:
/// line of text
/// path to the file located in the package
/// link to a resource on the Internet
/// It is advisable to indicate the resource type before resources, using the separator ":"
/// the program can infer the type from the file extension or file link
/// The following types of resources are provided:
/// * image
/// * audio
/// * video
/// * html
/// * md
/// * decardtc - text constructor json
/// * txt - text file
/// * text - text in field
///
/// html: for correct operation, the html must contain the line
/// <meta name="viewport" content="width=device-width, initial-scale=1.0">