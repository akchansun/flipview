#pragma once

class QWidget;
struct LinuxRelease;

// One combined launch dialog for usage tips and/or an update (not two sequential
// windows). Call after the main window is visible so a CLI image path can load first.
void runLaunchPrompts(QWidget* parent);

void presentCombinedLaunchDialog(QWidget* parent, const LinuxRelease& rel, bool showUpdate);
void startOnlineUpdateCheck(QWidget* parent);
