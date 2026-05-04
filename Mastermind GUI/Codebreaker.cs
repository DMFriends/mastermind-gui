using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace Mastermind_GUI
{
    public partial class Codebreaker : Form
    {
        private string[] guesses = new string[4];
        private int guessesIndex = 0;
        private int countColorsGuessed = 1;
        private int countCorrectColors = 0;
        private int countCorrectColorsInWrongSpot = 0;
        private int tries = 0;
        private string combinationStr = "";
        private readonly Codemaker codemaker;

        public Codebreaker(Codemaker cm)
        {
            InitializeComponent();
            codemaker = cm;
        }

        private void CheckCombination()
        {         
            string[] codemakerCombo = codemaker.Combination;
            if (codemakerCombo[guessesIndex] == guesses[guessesIndex])
            {
                countCorrectColors++;
            }

            if (codemakerCombo.Contains(guesses[guessesIndex]) && codemakerCombo[guessesIndex] != guesses[guessesIndex])
            {
                countCorrectColorsInWrongSpot++;
            }

            guessesIndex++;

            if (countColorsGuessed == 4)
            {
                tries++;
                if (tries == 10)
                {
                    string codemakerComboStr = string.Join(" ", codemakerCombo);
                    MessageBox.Show("Unfortunately, you ran out of tries. The combination was " +
                        codemakerComboStr + ". Better luck next time!",
                        "Game Over", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    Close();
                }

                if (countCorrectColors == 4)
                {
                    MessageBox.Show("Congratulations! You have guessed the combination!",
                        "Code Cracked", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    Close();
                }

                if (countCorrectColors != 4 && tries != 10)
                {
                    MessageBox.Show("You guessed " + countCorrectColors +
                        " color(s) correctly! " + countCorrectColorsInWrongSpot + " color(s) are not in the correct spot.",
                        "Combination Guess", MessageBoxButtons.OK, MessageBoxIcon.Information);

                    combinationStr = string.Join(" ", guesses);
                    lblGuesses.Text += tries.ToString() + "                   " + combinationStr;
                    //lblGuesses.Font = new Font("Microsoft Sans Serif", 10);
                    lblGuesses.Text += "\n                   " + countCorrectColors +
                        " color(s) in the correct spot\n                   " + countCorrectColorsInWrongSpot +
                        " color(s) not in the correct spot\n\n";

                    EnableAllButtons();

                    countColorsGuessed = 0;
                    countCorrectColors = 0;
                    countCorrectColorsInWrongSpot = 0;
                }
            }
        }

        private int Count(string[] ary)
        {
            for (int i = 0; i < ary.Length; i++)
            {
                if (ary[i] == null)
                {
                    return i;
                }
            }

            return ary.Length;
        }

        private void EnableAllButtons()
        {
            btnRed.Enabled = true;
            btnGreen.Enabled = true;
            btnBlue.Enabled = true;
            btnBlack.Enabled = true;
            btnWhite.Enabled = true;
            btnYellow.Enabled = true;
        }

        private void btnRed_Click(object sender, EventArgs e)
        {
            if (Count(guesses) == 4)
            {
                Array.Clear(guesses, 0, 4);
            }
            if (guessesIndex > 0 && Count(guesses) == 0)
            {
                guessesIndex = 0;
            }
            guesses[guessesIndex] = "Red";
            btnRed.Enabled = false;
            CheckCombination();
            countColorsGuessed++;
        }

        private void btnBlue_Click(object sender, EventArgs e)
        {
            if (Count(guesses) == 4)
            {
                Array.Clear(guesses, 0, 4);
            }
            if (guessesIndex > 0 && Count(guesses) == 0)
            {
                guessesIndex = 0;
            }
            guesses[guessesIndex] = "Blue";
            btnBlue.Enabled = false;
            CheckCombination();
            countColorsGuessed++;
        }

        private void btnGreen_Click(object sender, EventArgs e)
        {
            if (Count(guesses) == 4)
            {
                Array.Clear(guesses, 0, 4);
            }
            if (guessesIndex > 0 && Count(guesses) == 0)
            {
                guessesIndex = 0;
            }
            guesses[guessesIndex] = "Green";
            btnGreen.Enabled = false;
            CheckCombination();
            countColorsGuessed++;
        }

        private void btnWhite_Click(object sender, EventArgs e)
        {
            if (Count(guesses) == 4)
            {
                Array.Clear(guesses, 0, 4);
            }
            if (guessesIndex > 0 && Count(guesses) == 0)
            {
                guessesIndex = 0;
            }
            guesses[guessesIndex] = "White";
            btnWhite.Enabled = false;
            CheckCombination();
            countColorsGuessed++;
        }

        private void btnBlack_Click(object sender, EventArgs e)
        {
            if (Count(guesses) == 4)
            {
                Array.Clear(guesses, 0, 4);
            }
            if (guessesIndex > 0 && Count(guesses) == 0)
            {
                guessesIndex = 0;
            }
            guesses[guessesIndex] = "Black";
            btnBlack.Enabled = false;
            CheckCombination();
            countColorsGuessed++;
        }

        private void btnYellow_Click(object sender, EventArgs e)
        {
            if (Count(guesses) == 4)
            {
                Array.Clear(guesses, 0, 4);
            }
            if (guessesIndex > 0 && Count(guesses) == 0)
            {
                guessesIndex = 0;
            }
            guesses[guessesIndex] = "Yellow";
            btnYellow.Enabled = false;
            CheckCombination();
            countColorsGuessed++;
        }

        private void btnEndGame_Click(object sender, EventArgs e)
        {
            DialogResult result = MessageBox.Show("Are you sure you want to quit?", "Exit Game",
                MessageBoxButtons.YesNo, MessageBoxIcon.Warning);
            if (result == DialogResult.Yes)
            {
                Close();
            }
        }
    }
}
