#include <vector>
#include <iostream>
#include <sstream>
#include "NETALWrapper.hpp"

using namespace std;

const string NETALProgram = "./NETAL";

NETALWrapper::NETALWrapper(Graph* G1, Graph* G2, string args): WrappedMethod(G1, G2, "NETAL", args) {
	wrappedDir = "wrappedAlgorithms/NETAL";
}

// a: Alpha 0.0001
// b:
// c:
// i: Iterations 2
void NETALWrapper::loadDefaultParameters() {
	parameters = "-a 0.0001 -b 0 -c 1 -i 2";
}

string NETALWrapper::convertAndSaveGraph(Graph* graph, string name) {
	graph->writeGraphEdgeListFormatNETAL(name);
	return name;
}

string NETALWrapper::generateAlignment() {
    // Give the program execute permissions
	exec("cd " + wrappedDir + "; chmod +x "+ NETALProgram);

    // Run the program in the wrappedDir with the parameters
    string cmd = "cd " + wrappedDir + ";" + NETALProgram + " " + g1File + " " + g2File + " " + parameters;
    execPrintOutput(cmd);

    // Rename the alignment file
    string oldName = "\\(" + g1File + "-" + g2File + "*.alignment";
    string newName = g1File + "-" + g2File + ".alignment";
    exec("cd " + wrappedDir + "; mv " + oldName + " " + newName);

    return wrappedDir + "/" + newName;
}

Alignment NETALWrapper::loadAlignment(Graph* G1, Graph* G2, string fileName) {
    vector<string> lines = fileToStrings(fileName, true);
    string word;
    vector<ushort> mapping(G1->getNumNodes(), G2->getNumNodes());

    for (uint i = 0; i < lines.size(); ++i) {
    	istringstream line(lines[i]);
        vector<string> words;
        while (line >> word) words.push_back(word);

        if (words.size() == 3) {
        	mapping[atoi(words[0].c_str())] = atoi(words[2].c_str());
        }
    }
    return Alignment(mapping);
}

void NETALWrapper::deleteAuxFiles() {
    string evalFile = "\\(" + g1File + "-" + g2File + "*.eval";

    exec("cd " + wrappedDir + "; rm " + g1File + " " + g2File + " " + alignmentFile +
    		" " + evalFile + " simLog.txt alignmentDetails.txt" );
}