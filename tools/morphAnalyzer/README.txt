README
======
Version 1.8 (20130314)

Using the tokenizer
-------------------

java [-Xmx1024m] -jar tokenizer.jar <input> <output>

Example 1: java -Xmx1024m -jar tokenizer.jar file.txt file.xml
Example 2: java -Xmx1024m -jar tokenizer.jar corpus/ corpus_tokenized/

Note: If using the directory mode, the output directory must already exist.
      Try "mkdir corpus_tokenized" before example 2.

Using the analyzer (standalone)
-------------------------------

java -Xmx1G -jar morphAnalyzer.jar false tokenized.xml output.xml
java -Xmx1G -jar morphAnalyzer.jar false tokenized_dir/ output_dir/

Important note: Please use the analyzer on directories for proper output, single
                file usage might be bugged.

The "false" means to use the datafiles. Change to "true" to use the DB.

Using the analyzer (client-server)
----------------------------------

./RunTagger

Enter 4646

Then:

./RunClient 4646

Using the tagger (only tags)
----------------------------
java -cp morphAnalyzer.jar mila.tools.Processor -t <input> <output>

Note: Using the tagger requires preparation, including installing perl and
      the SRILM toolkit. Please contact the MILA lab engineer for assistance.
