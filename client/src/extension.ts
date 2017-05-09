/* --------------------------------------------------------------------------------------------
 * Copyright (c) Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See License.txt in the project root for license information.
 * ------------------------------------------------------------------------------------------ */
'use strict';

import * as net from 'net';

import { workspace, Disposable, ExtensionContext } from 'vscode';
import { LanguageClient, LanguageClientOptions, SettingMonitor, ServerOptions, ErrorAction, ErrorHandler, CloseAction, TransportKind } from 'vscode-languageclient';

// function startLangServer(command: string, documentSelector: string | string[]): Disposable {
//   const serverOptions: ServerOptions = {
//     command: command,
//   };
//   const clientOptions: LanguageClientOptions = {
//     documentSelector: documentSelector,
//   }
//   return new LanguageClient(command, serverOptions, clientOptions).start();
// }

function startLangServerTCP(addr: number, documentSelector: string | string[]): Disposable {
  let serverOptions: ServerOptions = function() {
    return new Promise((resolve, reject) => {
      var client = new net.Socket();
      client.connect(addr, "127.0.0.1", function() {
        resolve({
          reader: client,
          writer: client
        });
      });
    });
  }

  let clientOptions: LanguageClientOptions = {
    // Register the server for puppet manifests
    documentSelector: ['puppet'],
    // synchronize: {
    //   // Synchronize the setting section 'languageServerExample' to the server
    //   configurationSection: 'languageServerExample',
    //   // Notify the server about file changes to '.clientrc files contain in the workspace
    //   fileEvents: workspace.createFileSystemWatcher('**/.clientrc')
    // }
  }

  return new LanguageClient(`tcp lang server (port ${addr})`, serverOptions, clientOptions).start();
}

export function activate(context: ExtensionContext) {
    //context.subscriptions.push(startLangServer("pyls", ["python"]));
    // For TCP
    context.subscriptions.push(startLangServerTCP(8081, ["puppet"]));
}


// /* --------------------------------------------------------------------------------------------
//  * Copyright (c) Microsoft Corporation. All rights reserved.
//  * Licensed under the MIT License. See License.txt in the project root for license information.
//  * ------------------------------------------------------------------------------------------ */
// 'use strict';

// import * as path from 'path';

// import { workspace, Disposable, ExtensionContext } from 'vscode';
// import { LanguageClient, LanguageClientOptions, SettingMonitor, ServerOptions, TransportKind } from 'vscode-languageclient';

// export function activate(context: ExtensionContext) {

// 	// The server is implemented in node
// 	let serverModule = context.asAbsolutePath(path.join('server', 'server.js'));
// 	// The debug options for the server
// 	let debugOptions = { execArgv: ["--nolazy", "--debug=6009"] };
  
// 	// If the extension is launched in debug mode then the debug server options are used
// 	// Otherwise the run options are used
// 	let serverOptions: ServerOptions = {
// 		run : { module: serverModule, transport: TransportKind.ipc },
// 		debug: { module: serverModule, transport: TransportKind.ipc, options: debugOptions }
// 	}
  
// 	// Options to control the language client
// 	let clientOptions: LanguageClientOptions = {
// 		// Register the server for plain text documents
// 		documentSelector: ['plaintext'],
// 		synchronize: {
// 			// Synchronize the setting section 'languageServerExample' to the server
// 			configurationSection: 'languageServerExample',
// 			// Notify the server about file changes to '.clientrc files contain in the workspace
// 			fileEvents: workspace.createFileSystemWatcher('**/.clientrc')
// 		}
// 	}
  
// 	// Create the language client and start the client.
// 	let disposable = new LanguageClient('languageServerExample', 'Language Server Example', serverOptions, clientOptions).start();
  
// 	// Push the disposable to the context's subscriptions so that the 
// 	// client can be deactivated on extension deactivation
// 	context.subscriptions.push(disposable);
// }
