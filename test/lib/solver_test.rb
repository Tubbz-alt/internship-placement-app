require 'test_helper'

describe Solver do
  let (:classroom) { Classroom.find_by(name: "solver_test") }
  let (:solver) { Solver.new(classroom) }

  describe '#initialize' do
    it "rejects classrooms with mismatched students and companies" do
      Classroom.transaction do
        classroom = Classroom.create!(name: 'solver scale test', creator: User.first)
        23.times do |i|
          classroom.students.create!(name: "scale test student #{i}")
        end

        # The extra [1] between the 3 and the 2s is important
        # for making student assignments line up later
        company_slots = [3] + [1] + ([2] * 5) + ([1] * 10)
        company_slots.sum.must_equal 24
        company_slots.each_with_index do |s, i|
          classroom.companies.create!(name: "scale test company #{i}", slots: s)
        end

        expect { Solver.new(classroom) }.must_raise ArgumentError
      end
    end

    it "builds a matrix of correct size" do
      expected_rows = classroom.students.count
      solver.matrix.row_count.must_equal expected_rows

      expected_cols = classroom.companies.reduce(0) do |sum, co|
        sum + co.slots
      end
      solver.matrix.column_count.must_equal expected_cols
    end

    it "builds a matrix with correct values" do
      solver.matrix.each_with_index do |value, row, col|
        interview = Interview.find_by(
          student: solver.students[row],
          company: solver.companies[col]
        )

        rank = Ranking.find_by(
          interview: interview
        )

        if rank.nil?
          value.must_equal Float::INFINITY
        else
          value.must_be :>=, 0
          value.must_be :<=, 24
        end
      end

      puts
      puts solver.matrix
      puts
    end

    it "applies the initial reduction" do
      solver.matrix.row_count.times do |r|
        solver.matrix.row(r).min.must_equal 0
      end
      solver.matrix.column_count.times do |c|
        solver.matrix.column(c).min.must_equal 0
      end
    end
  end

  describe "#solve" do
    def check_pairings(pairings, classroom)
      pairings.length.must_equal classroom.students.length

      # Check for duplicates
      students = {}
      companies = Hash.new([])
      pairings.each do |pair|
        pair.must_be_kind_of Pairing
        classroom.students.must_include pair.student
        classroom.companies.must_include pair.company

        students.wont_include pair.student.name
        students[pair.student.name] = pair.company.name

        companies[pair.company.name].wont_include pair.student.name
        companies[pair.company.name] << pair.student.name
      end
      companies.each do |name, students|
        company = classroom.companies.find_by(name: name)
        students.length.must_equal company.slots
      end

      # TODO DPR: figure out a way to check that the set of
      # pairings is optimal / stable / something
    end

    it "produces an array" do
      pairings = solver.solve
      check_pairings(pairings, classroom)
    end

    it "produces an error on an unsolvable classroom" do
      classroom.students.each do |student|
        student.interviews.each do |interview|
          interview.ranking.destroy
        end
      end

      classroom = Classroom.create(creator: User.first, name: "Unsolveable")

      student1 = Student.create!(name: "Student 1", classroom: classroom)
      student2 = Student.create!(name: "Student 2", classroom: classroom)
      student3 = Student.create!(name: "Student 3", classroom: classroom)
      student4 = Student.create!(name: "Student 4", classroom: classroom)

      company1 = Company.create!(name: "Company 1", classroom: classroom, slots: 2)
      company2 = Company.create!(name: "Company 2", classroom: classroom, slots: 1)
      company3 = Company.create!(name: "Company 3", classroom: classroom, slots: 1)

      # students 1, 2 and 3 interviewed with company 1
      interview = Interview.create!(
        student: student1,
        company: company1,
        scheduled_at: Time.now + 1.day
      )
      InterviewFeedback.create!(interview: interview,
                                interviewer_name: "Niv Mizzet",
                                interview_result: 5,
                                result_explanation: "Very creative solution!")
      Ranking.create!(interview: interview, student_preference: 5)

      interview = Interview.create!(
        student: student2,
        company: company1,
        scheduled_at: Time.now + 1.day
      )
      InterviewFeedback.create!(interview: interview,
                                interviewer_name: "Niv Mizzet",
                                interview_result: 5,
                                result_explanation: "Very creative solution!")
      Ranking.create!(interview: interview, student_preference: 5)

      interview = Interview.create!(
        student: student3,
        company: company1,
        scheduled_at: Time.now + 1.day
      )
      InterviewFeedback.create!(interview: interview,
                                interviewer_name: "Niv Mizzet",
                                interview_result: 5,
                                result_explanation: "Very creative solution!")
      Ranking.create!(interview: interview, student_preference: 5)

      # student 4 interviewed with companies 2 and 3
      interview = Interview.create!(
        student: student4,
        company: company2,
        scheduled_at: Time.now + 1.day
      )
      InterviewFeedback.create!(interview: interview,
                                interviewer_name: "Niv Mizzet",
                                interview_result: 5,
                                result_explanation: "Very creative solution!")
      Ranking.create!(interview: interview, student_preference: 5)

      interview = Interview.create!(
        student: student4,
        company: company3,
        scheduled_at: Time.now + 1.day
      )
      InterviewFeedback.create!(interview: interview,
                                interviewer_name: "Niv Mizzet",
                                interview_result: 5,
                                result_explanation: "Very creative solution!")
      Ranking.create!(interview: interview, student_preference: 5)

      solver = Solver.new(classroom)
      proc {
        solver.solve
      }.must_raise SolutionError
    end


    SCALE = 24
    INTERVIEWS_PER_SLOT = 6
    def build_classroom()
      # Build students and companies
      classroom = nil
      Classroom.transaction do
        classroom = Classroom.create!(name: 'solver scale test', creator: User.first)
        SCALE.times do |i|
          classroom.students.create!(name: "scale test student #{i}")
        end

        # The extra [1] between the 3 and the 2s is important
        # for making student assignments line up later
        company_slots = [3] + [1] + ([2] * 5) + ([1] * 10)
        company_slots.sum.must_equal SCALE
        company_slots.each_with_index do |s, i|
          classroom.companies.create!(name: "scale test company #{i}", slots: s)
        end

        # Generate rankings
        # We make six shuffled lists of students and consume them
        # in order, to avoid ending up with a student needing to
        # inteveiw at the same company multiple times at the end
        available_students = 6.times.map do
          classroom.students.to_a.shuffle()
        end
        student_tier = []

        classroom.companies.each do |company|
          # puts "\nCompany #{company.name} of #{company_slots.length}"

          # Each company interviews 6 students per slot
          interview_count = company.slots * INTERVIEWS_PER_SLOT
          if student_tier.empty?
            # puts "Begin tier #{available_students.length}"
            student_tier = available_students.pop
          end
          students = student_tier.pop(interview_count)

          # Shouldn't run out of students
          if students.length != interview_count
            puts "Hit the bad state. Remaining students:"
            students.each do |s|
              puts "  #{s.name} with #{s.rankings.count} rankings"
            end
          end
          students.length.must_equal interview_count

          # Build a ranking for this company for each student
          students.each do |student|
            interview = student.interviews.create!(
              company: company,
              scheduled_at: Time.now + 1.day
            )

            interview.interview_feedbacks.create!(
              interviewer_name: "Archmage Jodah",
              interview_result: rand(5) + 1,
              result_explanation: "Study harder"
            )

            Ranking.create!(
              interview: interview,
              student_preference: rand(5) + 1,
            )
          end
        end

        # We should have exactly exhausted our pool of students
        available_students.must_be_empty
      end

      return classroom
    end

    def solve_classroom(classroom)
      # We're set up - time to build and run the solver
      start_time = Time.now
      solver = Solver.new(classroom)
      pairings = solver.solve
      total_time = Time.now - start_time

      check_pairings(pairings, classroom)

      return total_time, solver.iterations
    end

    it "Can handle a full-scale classroom" do
      classroom = build_classroom()
      total_time, iterations = solve_classroom(classroom)
      puts "Converged in #{total_time} seconds, #{iterations} iterations"
    end

    it "Always converges" do
      skip "takes a long-ass time"
      # Haven't looked into actually proving this (it probably doesn't), so for
      # now we'll just try it 100 times and see what we get

      times = []
      iterations = []
      failures = 0
      start_time = Time.now
      100.times do |i|
        begin
          classroom = build_classroom()
          run_time, run_iterations = solve_classroom(classroom)
          puts "Run #{i} finished in #{run_time} seconds, #{run_iterations} iterations"
          times << run_time
          iterations << run_iterations
        rescue SolutionError
          # TODO: give some information about what the arrangement looked
          # like so we can come up with a characterization of these
          # pathological scenarios
          puts "Found a case that failed to converge!"
          failures += 1
        end
      end

      # puts times
      # puts iterations

      average_time = 1.0 * times.sum / times.length
      average_iters = 1.0 * iterations.sum / iterations.length

      puts "Finished 100 runs in #{Time.now - start_time} seconds"
      puts "Avg run time: #{average_time}"
      puts "Avg iterations: #{average_iters}"
      puts "Failure rate: #{failures}"
    end
  end
end
