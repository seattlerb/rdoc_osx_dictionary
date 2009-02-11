#
# Makefile
#
#
#

###########################

# You need to edit these values.

DICT_NAME				=	"RubyAndGems"
DICT_SRC_PATH		=	RubyGemsDictionary.xml
CSS_PATH				=	RubyGemsDictionary.css
PLIST_PATH			=	RubyGemsInfo.plist

DICT_BUILD_OPTS		=
# Suppress adding supplementary key.
# DICT_BUILD_OPTS		=	-s 0	# Suppress adding supplementary key.

###########################

# The DICT_BUILD_TOOL_DIR value is used also in "build_dict.sh" script.
# You need to set it when you invoke the script directly.

DICT_BUILD_TOOL_DIR	=	"/Developer/Extras/Dictionary Development Kit"
DICT_BUILD_TOOL_BIN	=	"$(DICT_BUILD_TOOL_DIR)/bin"

###########################

DICT_DEV_KIT_OBJ_DIR	=	./objects
export	DICT_DEV_KIT_OBJ_DIR

DESTINATION_FOLDER	=	~/Library/Dictionaries
RM			=	/bin/rm

###########################

all: xml dict
	echo "Done."
	open -a Dictionary

xml:
	./rdoc_osx_dictionary.rb

dict:
	"$(DICT_BUILD_TOOL_BIN)/build_dict.sh" $(DICT_BUILD_OPTS) $(DICT_NAME) $(DICT_SRC_PATH) $(CSS_PATH) $(PLIST_PATH)

install:
	echo "Installing into $(DESTINATION_FOLDER)".
	mkdir -p $(DESTINATION_FOLDER)
	ditto --noextattr --norsrc $(DICT_DEV_KIT_OBJ_DIR)/$(DICT_NAME).dictionary  $(DESTINATION_FOLDER)/$(DICT_NAME).dictionary
	touch $(DESTINATION_FOLDER)
	echo "Done."
	echo "To test the new dictionary, try Dictionary.app."

validate: xml
	java -jar jing-20081028/bin/jing.jar documents/DictionarySchema/AppleDictionarySchema.rng RubyGemsDictionary.xml 

purge:
	rm ~/.ri/cache/*.xml

clean:
	$(RM) -rf $(DICT_DEV_KIT_OBJ_DIR)
