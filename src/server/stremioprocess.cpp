#include "stremioprocess.h"

#ifdef WIN32
#include <windows.h>
#include <QDebug>
HANDLE jobMainProcess = NULL;
#endif

#define ERR_BUF_LINES 200

void Process::start(const QString &program, const QVariantList &arguments, QString mPattern) {
#ifdef WIN32
    // On Windows, ensure we have a job object to tie child processes to
    if (!jobMainProcess) {
        jobMainProcess = CreateJobObject(NULL, NULL);
        if (!jobMainProcess) {
            qDebug() << "[WIN32] Could not create WIN32 Job. Child processes may leak.";
        } else {
            JOBOBJECT_EXTENDED_LIMIT_INFORMATION jeli = { 0 };
            jeli.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE | JOB_OBJECT_LIMIT_DIE_ON_UNHANDLED_EXCEPTION;
            if (!SetInformationJobObject(jobMainProcess, JobObjectExtendedLimitInformation, &jeli, sizeof(jeli))) {
                qDebug() << "[WIN32] Failed to SetInformationJobObject:" << GetLastError();
            }
        }
    }
#endif

    QStringList args;
    for (int i = 0; i < arguments.length(); i++)
        args << arguments[i].toString();

    if (!mPattern.isEmpty()) {
        this->magicPattern = mPattern.toLatin1();
        this->magicPatternFound = false;
    }

    connect(this, &QProcess::errorOccurred, this, &Process::onError);
    connect(this, &QProcess::readyReadStandardOutput, this, &Process::onOutput);
    connect(this, &QProcess::readyReadStandardError, this, &Process::onStdErr);
    connect(this, &QProcess::started, this, &Process::onStarted);

    QProcess::start(program, args);
}

bool Process::waitForFinished(int msecs) {
    return QProcess::waitForFinished(msecs);
}

void Process::onError(QProcess::ProcessError error) {
    this->errorThrown(error);
}

void Process::onOutput() {
    setReadChannel(QProcess::ProcessChannel::StandardOutput);
    while (this->canReadLine()) {
        QByteArray line = this->readLine();
        std::cout << line.toStdString();
        if (!this->magicPatternFound) checkServerAddressMessage(line);
    }
}

void Process::onStdErr() {
    setReadChannel(QProcess::ProcessChannel::StandardError);
    while (this->canReadLine()) {
        QByteArray line = this->readLine();
        errBuff.append(line);
        if (errBuff.size() > ERR_BUF_LINES) {
            errBuff.removeFirst();
        }
        std::cerr << line.toStdString();
    }
}

QByteArray Process::getErrBuff() {
    return errBuff.join();
}

void Process::onStarted() {
#ifdef WIN32
    DWORD pid = static_cast<DWORD>(this->processId());
    if (pid == 0) {
        qDebug() << "[WIN32] Invalid PID, cannot assign to job object.";
        return;
    }

    HANDLE processHandle = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
    if (!processHandle) {
        qDebug() << "[WIN32] OpenProcess failed:" << GetLastError();
        return;
    }

    if (!AssignProcessToJobObject(jobMainProcess, processHandle)) {
        qDebug() << "[WIN32] AssignProcessToJobObject failed:" << GetLastError();
    }

    CloseHandle(processHandle);
#endif
}

void Process::checkServerAddressMessage(QByteArray message) {
    if (message.startsWith(this->magicPattern)) {
        this->magicPatternFound = true;
        addressReady(QString(message.remove(0, this->magicPattern.size())));
    }
}
