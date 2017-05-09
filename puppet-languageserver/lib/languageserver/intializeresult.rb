# module LanguageServer

#   class InitializeResult
#     attr_accessor :capabilities

#      def initialize(init = nil)
#        capabilities = ServerCapabilities.new(init)
#      end
#   end

#   class ServerCapabilities
#     # Defines how text documents are synced. Is either a detailed structure defining each notification or for backwards compatibility the TextDocumentSyncKind number.
#     attr_accessor :textDocumentSync?: TextDocumentSyncOptions | number;

#     #The server provides hover support.
#     attr_accessor :hoverProvider?

#     # The server provides completion support.
#     attr_accessor :completionProvider?: CompletionOptions;
#   /**
#    * The server provides signature help support.
#    */
#   signatureHelpProvider?: SignatureHelpOptions;
#   /**
#    * The server provides goto definition support.
#    */
#   definitionProvider?: boolean;
#   /**
#    * The server provides find references support.
#    */
#   referencesProvider?: boolean;
#   /**
#    * The server provides document highlight support.
#    */
#   documentHighlightProvider?: boolean;
#   /**
#    * The server provides document symbol support.
#    */
#   documentSymbolProvider?: boolean;
#   /**
#    * The server provides workspace symbol support.
#    */
#   workspaceSymbolProvider?: boolean;
#   /**
#    * The server provides code actions.
#    */
#   codeActionProvider?: boolean;
#   /**
#    * The server provides code lens.
#    */
#   codeLensProvider?: CodeLensOptions;
#   /**
#    * The server provides document formatting.
#    */
#   documentFormattingProvider?: boolean;
#   /**
#    * The server provides document range formatting.
#    */
#   documentRangeFormattingProvider?: boolean;
#   /**
#    * The server provides document formatting on typing.
#    */
#   documentOnTypeFormattingProvider?: DocumentOnTypeFormattingOptions;
#   /**
#    * The server provides rename support.
#    */
#   renameProvider?: boolean;
#   /**
#    * The server provides document link support.
#    */
#   documentLinkProvider?: DocumentLinkOptions;
#   /**
#    * The server provides execute command support.
#    */
#   executeCommandProvider?: ExecuteCommandOptions;
#   /**
#    * Experimental server capabilities.
#    */
#   experimental?: any;
# }

#   end
# end
